import random
from datetime import timedelta

from django.core.cache import cache
from django.utils import timezone
from rest_framework import status
from rest_framework.generics import RetrieveAPIView
from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.viewsets import ModelViewSet

from apps.courses.access import user_can_access_lesson
from apps.lessons.models import Lesson
from apps.progress.models import LessonProgress, QuizAttempt, QuizResult
from apps.gamification.models import Badge
from apps.gamification.xp_utils import apply_daily_streak_bonus, grant_xp

from .models import Answer, Question, Quiz
from .serializers import (
    AdminAnswerSerializer,
    AdminQuestionSerializer,
    AdminQuizSerializer,
    QuizSerializer,
    QuizSubmitSerializer,
)

PASS_THRESHOLD = 80
QUIZ_POOL_SIZE = 10
QUIZ_DAILY_ATTEMPT_LIMIT = 5
QUIZ_COOLDOWN_MINUTES = 3
QUIZ_BASE_XP = 20
QUIZ_PERFECT_BONUS_XP = 10
QUIZ_HIGH_SCORE_BONUS_XP = 5


def _quiz_session_key(user_id: int, quiz_id: int) -> str:
    return f"quiz_session:{user_id}:{quiz_id}"


class QuizByLessonView(RetrieveAPIView):
    serializer_class = QuizSerializer
    lookup_field = "lesson_id"
    queryset = Quiz.objects.prefetch_related("questions__answers")
    permission_classes = [IsAuthenticated]

    def retrieve(self, request, *args, **kwargs):
        if request.user.is_staff:
            return Response(
                {"detail": "Quizzes are available to students only."},
                status=status.HTTP_403_FORBIDDEN,
            )
        quiz = self.get_object()
        lesson = Lesson.objects.select_related("module__course").get(pk=quiz.lesson_id)
        if not user_can_access_lesson(request.user, lesson):
            return Response(
                {
                    "detail": "Subscribe to this course to take quizzes and earn progress.",
                    "code": "subscription_required",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        progress, _ = LessonProgress.objects.get_or_create(
            user=request.user,
            lesson_id=quiz.lesson_id,
        )
        if not progress.video_watched:
            return Response(
                {
                    "detail": "Quiz unlocks after watching at least 80% of the lesson video.",
                    "code": "quiz_locked_video_required",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        attempts_today = QuizAttempt.objects.filter(
            user=request.user,
            quiz=quiz,
            submitted_at__date=timezone.localdate(),
        ).count()
        attempts_left = max(0, QUIZ_DAILY_ATTEMPT_LIMIT - attempts_today)

        last_attempt = QuizAttempt.objects.filter(user=request.user, quiz=quiz).first()
        cooldown_seconds = 0
        if last_attempt and not last_attempt.passed:
            unlock_at = last_attempt.submitted_at + timedelta(minutes=QUIZ_COOLDOWN_MINUTES)
            if unlock_at > timezone.now():
                cooldown_seconds = int((unlock_at - timezone.now()).total_seconds())

        all_questions = list(quiz.questions.all().prefetch_related("answers"))
        random.shuffle(all_questions)
        selected_questions = all_questions[: min(QUIZ_POOL_SIZE, len(all_questions))]
        selected_ids = [q.id for q in selected_questions]
        cache.set(
            _quiz_session_key(request.user.id, quiz.id),
            selected_ids,
            timeout=60 * 30,
        )

        payload_questions = []
        for idx, question in enumerate(selected_questions, start=1):
            answers = list(question.answers.all())
            random.shuffle(answers)
            payload_questions.append(
                {
                    "id": question.id,
                    "text": question.text,
                    "order": idx,
                    "answers": [{"id": a.id, "text": a.text} for a in answers],
                }
            )

        return Response(
            {
                "id": quiz.id,
                "title": quiz.title,
                "questions": payload_questions,
                "rules": {
                    "daily_attempt_limit": QUIZ_DAILY_ATTEMPT_LIMIT,
                    "attempts_today": attempts_today,
                    "attempts_left": attempts_left,
                    "cooldown_seconds": cooldown_seconds,
                    "reading_checkpoint_required": True,
                    "pass_threshold": PASS_THRESHOLD,
                },
            }
        )


class QuizSubmitView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        if request.user.is_staff:
            return Response(
                {"detail": "Quizzes are available to students only."},
                status=status.HTTP_403_FORBIDDEN,
            )
        try:
            quiz = Quiz.objects.prefetch_related("questions__answers").get(pk=pk)
        except Quiz.DoesNotExist:
            return Response({"detail": "Quiz not found"}, status=status.HTTP_404_NOT_FOUND)

        lesson = Lesson.objects.select_related("module__course").get(pk=quiz.lesson_id)
        if not user_can_access_lesson(request.user, lesson):
            return Response(
                {
                    "detail": "Subscribe to this course to take quizzes and earn progress.",
                    "code": "subscription_required",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        progress, _ = LessonProgress.objects.get_or_create(
            user=request.user,
            lesson_id=quiz.lesson_id,
        )
        if not progress.video_watched:
            return Response(
                {
                    "detail": "Quiz unlocks after watching at least 80% of the lesson video.",
                    "code": "quiz_locked_video_required",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        attempts_today_qs = QuizAttempt.objects.filter(
            user=request.user,
            quiz=quiz,
            submitted_at__date=timezone.localdate(),
        )
        attempts_today = attempts_today_qs.count()
        if attempts_today >= QUIZ_DAILY_ATTEMPT_LIMIT:
            return Response(
                {
                    "detail": "Daily attempt limit reached for this quiz. Try again tomorrow.",
                    "code": "quiz_daily_limit_reached",
                    "daily_attempt_limit": QUIZ_DAILY_ATTEMPT_LIMIT,
                },
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        last_attempt = QuizAttempt.objects.filter(user=request.user, quiz=quiz).first()
        if last_attempt and not last_attempt.passed:
            unlock_at = last_attempt.submitted_at + timedelta(minutes=QUIZ_COOLDOWN_MINUTES)
            if unlock_at > timezone.now():
                wait_seconds = int((unlock_at - timezone.now()).total_seconds())
                return Response(
                    {
                        "detail": "Please wait before retrying this quiz.",
                        "code": "quiz_cooldown_active",
                        "retry_after_seconds": wait_seconds,
                    },
                    status=status.HTTP_429_TOO_MANY_REQUESTS,
                )

        ser = QuizSubmitSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        if not ser.validated_data.get("confirm_reading_checkpoint", False):
            return Response(
                {
                    "detail": "Confirm the reading checkpoint before submitting.",
                    "code": "reading_checkpoint_required",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        submitted = ser.validated_data["answers"]

        session_ids = cache.get(_quiz_session_key(request.user.id, quiz.id))
        questions_qs = quiz.questions.all()
        if session_ids:
            questions_qs = questions_qs.filter(id__in=session_ids)
        questions = list(questions_qs.prefetch_related("answers"))

        total = len(questions)
        if total == 0:
            return Response({"detail": "No questions"}, status=status.HTTP_400_BAD_REQUEST)

        correct = 0
        for question in questions:
            chosen_id = submitted.get(str(question.id))
            if chosen_id is not None:
                try:
                    answer = Answer.objects.get(pk=chosen_id, question=question)
                    if answer.is_correct:
                        correct += 1
                except Answer.DoesNotExist:
                    pass

        score = round((correct / total) * 100)
        passed = score >= PASS_THRESHOLD
        attempt_no = QuizAttempt.objects.filter(user=request.user, quiz=quiz).count() + 1

        xp_multiplier = 1.0 if attempt_no == 1 else (0.7 if attempt_no == 2 else 0.4)
        xp_awarded = 0

        result, _ = QuizResult.objects.update_or_create(
            user=request.user,
            quiz=quiz,
            defaults={"score": score, "passed": passed},
        )

        lesson_completed = False
        if passed:
            if not progress.quiz_passed or score > progress.quiz_score:
                progress.quiz_passed = True
                progress.quiz_score = score
                progress.save(update_fields=["quiz_passed", "quiz_score"])
            lesson_completed = progress.check_completion()

            base_xp = int(round(QUIZ_BASE_XP * xp_multiplier))
            grant_xp(request.user, base_xp, f"Quiz {quiz.id} passed (attempt {attempt_no})")
            xp_awarded += base_xp

            if attempt_no == 1 and score >= 90:
                quality_bonus = int(round(QUIZ_HIGH_SCORE_BONUS_XP * xp_multiplier))
                grant_xp(request.user, quality_bonus, f"High-score bonus for quiz {quiz.id}")
                xp_awarded += quality_bonus

            if score == 100:
                perfect_bonus = int(round(QUIZ_PERFECT_BONUS_XP * xp_multiplier))
                grant_xp(request.user, perfect_bonus, f"Perfect score bonus for quiz {quiz.id}")
                xp_awarded += perfect_bonus
                Badge.objects.get_or_create(user=request.user, badge_type="perfect_score")
                if attempt_no == 1:
                    Badge.objects.get_or_create(user=request.user, badge_type="first_try_perfect")

            xp_awarded += apply_daily_streak_bonus(request.user)

            passed_count = QuizResult.objects.filter(user=request.user, passed=True).count()
            if passed_count == 1:
                Badge.objects.get_or_create(user=request.user, badge_type="first_quiz")

        QuizAttempt.objects.create(
            user=request.user,
            quiz=quiz,
            attempt_no=attempt_no,
            score=score,
            passed=passed,
            xp_awarded=xp_awarded,
        )

        return Response({
            "score": score,
            "correct": correct,
            "total": total,
            "passed": passed,
            "lesson_completed": lesson_completed,
            "attempt_no": attempt_no,
            "xp_awarded": xp_awarded,
            "xp_multiplier": xp_multiplier,
        })


# ── Admin CRUD ──

class AdminQuizViewSet(ModelViewSet):
    serializer_class = AdminQuizSerializer
    permission_classes = [IsAdminUser]

    def get_queryset(self):
        qs = Quiz.objects.all()
        lesson_id = self.request.query_params.get("lesson")
        if lesson_id:
            qs = qs.filter(lesson_id=lesson_id)
        return qs


class AdminQuestionViewSet(ModelViewSet):
    serializer_class = AdminQuestionSerializer
    permission_classes = [IsAdminUser]

    def get_queryset(self):
        qs = Question.objects.all()
        quiz_id = self.request.query_params.get("quiz")
        if quiz_id:
            qs = qs.filter(quiz_id=quiz_id)
        return qs


class AdminAnswerViewSet(ModelViewSet):
    serializer_class = AdminAnswerSerializer
    permission_classes = [IsAdminUser]

    def get_queryset(self):
        qs = Answer.objects.all()
        question_id = self.request.query_params.get("question")
        if question_id:
            qs = qs.filter(question_id=question_id)
        return qs

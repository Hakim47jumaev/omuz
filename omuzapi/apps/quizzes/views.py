from rest_framework import status
from rest_framework.generics import RetrieveAPIView
from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.viewsets import ModelViewSet

from apps.progress.models import LessonProgress, QuizResult

from .models import Answer, Question, Quiz
from .serializers import (
    AdminAnswerSerializer,
    AdminQuestionSerializer,
    AdminQuizSerializer,
    QuizSerializer,
    QuizSubmitSerializer,
)

PASS_THRESHOLD = 80


class QuizByLessonView(RetrieveAPIView):
    serializer_class = QuizSerializer
    lookup_field = "lesson_id"
    queryset = Quiz.objects.prefetch_related("questions__answers")
    permission_classes = [IsAuthenticated]

    def retrieve(self, request, *args, **kwargs):
        if request.user.is_staff:
            return Response(
                {"detail": "Квизы доступны только студентам."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().retrieve(request, *args, **kwargs)


class QuizSubmitView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        if request.user.is_staff:
            return Response(
                {"detail": "Квизы доступны только студентам."},
                status=status.HTTP_403_FORBIDDEN,
            )
        try:
            quiz = Quiz.objects.prefetch_related("questions__answers").get(pk=pk)
        except Quiz.DoesNotExist:
            return Response({"detail": "Quiz not found"}, status=status.HTTP_404_NOT_FOUND)

        ser = QuizSubmitSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        submitted = ser.validated_data["answers"]

        total = quiz.questions.count()
        if total == 0:
            return Response({"detail": "No questions"}, status=status.HTTP_400_BAD_REQUEST)

        correct = 0
        for question in quiz.questions.all():
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

        result, _ = QuizResult.objects.update_or_create(
            user=request.user,
            quiz=quiz,
            defaults={"score": score, "passed": passed},
        )

        lesson_completed = False
        if passed:
            progress, _ = LessonProgress.objects.get_or_create(
                user=request.user, lesson_id=quiz.lesson_id,
            )
            if not progress.quiz_passed or score > progress.quiz_score:
                progress.quiz_passed = True
                progress.quiz_score = score
                progress.save(update_fields=["quiz_passed", "quiz_score"])
            lesson_completed = progress.check_completion()

        return Response({
            "score": score,
            "correct": correct,
            "total": total,
            "passed": passed,
            "lesson_completed": lesson_completed,
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

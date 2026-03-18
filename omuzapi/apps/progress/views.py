from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import LessonProgress, QuizResult
from .serializers import LessonProgressSerializer, QuizResultSerializer


class MarkVideoWatchedView(APIView):
    """Called when 80% of video is watched."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        lesson_id = request.data.get("lesson_id")
        if not lesson_id:
            return Response({"detail": "lesson_id required"}, status=status.HTTP_400_BAD_REQUEST)

        progress, _ = LessonProgress.objects.select_related("lesson").get_or_create(
            user=request.user, lesson_id=lesson_id,
        )
        if not progress.video_watched:
            progress.video_watched = True
            progress.save(update_fields=["video_watched"])
            progress.refresh_from_db()
            progress.check_completion()

        return Response({
            "video_watched": progress.video_watched,
            "quiz_passed": progress.quiz_passed,
            "is_completed": progress.is_completed,
        })


class LessonStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, lesson_id):
        from apps.lessons.models import Lesson
        try:
            lesson = Lesson.objects.get(pk=lesson_id)
        except Lesson.DoesNotExist:
            return Response({"detail": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        has_quiz = hasattr(lesson, "quiz")

        try:
            progress = LessonProgress.objects.get(user=request.user, lesson_id=lesson_id)
            return Response({
                "video_watched": progress.video_watched,
                "quiz_passed": progress.quiz_passed,
                "quiz_score": progress.quiz_score,
                "is_completed": progress.is_completed,
                "has_quiz": has_quiz,
            })
        except LessonProgress.DoesNotExist:
            return Response({
                "video_watched": False,
                "quiz_passed": False,
                "quiz_score": 0,
                "is_completed": False,
                "has_quiz": has_quiz,
            })


class CourseProgressView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, course_id):
        completed_ids = list(
            LessonProgress.objects.filter(
                user=request.user,
                lesson__module__course_id=course_id,
                is_completed=True,
            ).values_list("lesson_id", flat=True)
        )
        return Response({"completed_lesson_ids": completed_ids})


class ProgressOverview(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        lessons = LessonProgress.objects.filter(user=request.user, is_completed=True)
        quizzes = QuizResult.objects.filter(user=request.user, passed=True)

        return Response({
            "completed_lessons": lessons.count(),
            "passed_quizzes": quizzes.count(),
            "lessons": LessonProgressSerializer(lessons, many=True).data,
            "quizzes": QuizResultSerializer(quizzes, many=True).data,
        })

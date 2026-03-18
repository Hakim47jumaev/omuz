from django.db.models import Avg, Count, Q

from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.courses.models import Course
from apps.lessons.models import Lesson
from apps.progress.models import LessonProgress, QuizResult
from apps.quizzes.models import Quiz
from apps.users.models import User

from .models import Badge, UserXP, XPTransaction
from .serializers import (
    BadgeSerializer,
    LeaderboardEntrySerializer,
    UserXPSerializer,
    XPTransactionSerializer,
)


class ProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        xp, _ = UserXP.objects.get_or_create(user=request.user)
        badges = Badge.objects.filter(user=request.user).order_by("-earned_at")
        history = XPTransaction.objects.filter(user=request.user).order_by("-created_at")[:20]

        return Response({
            "user": {
                "id": request.user.id,
                "phone": request.user.phone,
                "first_name": request.user.first_name,
                "last_name": request.user.last_name,
            },
            "xp": UserXPSerializer(xp).data,
            "badges": BadgeSerializer(badges, many=True).data,
            "xp_history": XPTransactionSerializer(history, many=True).data,
        })


class LeaderboardView(APIView):
    def get(self, request):
        top = UserXP.objects.select_related("user").order_by("-total_xp")[:20]
        data = []
        for rank, entry in enumerate(top, start=1):
            data.append({
                "rank": rank,
                "first_name": entry.user.first_name,
                "last_name": entry.user.last_name,
                "total_xp": entry.total_xp,
                "level": entry.level,
            })
        return Response(LeaderboardEntrySerializer(data, many=True).data)


class AnalyticsView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        total_users = User.objects.count()
        total_courses = Course.objects.count()
        total_lessons = Lesson.objects.count()
        total_quizzes = Quiz.objects.count()

        completed_lessons = LessonProgress.objects.filter(is_completed=True).count()
        videos_watched = LessonProgress.objects.filter(video_watched=True).count()
        quizzes_passed = QuizResult.objects.filter(passed=True).count()
        quizzes_failed = QuizResult.objects.filter(passed=False).count()

        avg_quiz_score = QuizResult.objects.aggregate(avg=Avg("score"))["avg"] or 0

        top_courses = (
            Course.objects.annotate(
                completions=Count(
                    "modules__lessons__lessonprogress",
                    filter=Q(modules__lessons__lessonprogress__is_completed=True),
                )
            )
            .order_by("-completions")[:5]
            .values("id", "title", "completions")
        )

        active_users = (
            LessonProgress.objects.values("user")
            .distinct()
            .count()
        )

        return Response({
            "overview": {
                "total_users": total_users,
                "active_users": active_users,
                "total_courses": total_courses,
                "total_lessons": total_lessons,
                "total_quizzes": total_quizzes,
            },
            "progress": {
                "completed_lessons": completed_lessons,
                "videos_watched": videos_watched,
                "quizzes_passed": quizzes_passed,
                "quizzes_failed": quizzes_failed,
                "avg_quiz_score": round(avg_quiz_score, 1),
            },
            "top_courses": list(top_courses),
        })

from django.db.models import Avg, Count, Max, Min, Q, Sum
from django.db.models.functions import TruncDate

from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.courses.models import Course
from apps.lessons.models import Lesson
from apps.progress.models import LessonProgress, QuizResult
from apps.quizzes.models import Quiz
from apps.users.models import Transaction, User

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
        # Для админа не показываем историю XP.
        if request.user.is_staff:
            history = XPTransaction.objects.none()
        else:
            history = XPTransaction.objects.filter(user=request.user).order_by("-created_at")[:20]

        return Response({
            "user": {
                "id": request.user.id,
                "phone": request.user.phone,
                "first_name": request.user.first_name,
                "last_name": request.user.last_name,
                "avatar_url": request.build_absolute_uri(request.user.avatar.url)
                if request.user.avatar
                else None,
                "is_staff": request.user.is_staff,
            },
            "xp": UserXPSerializer(xp).data,
            "badges": BadgeSerializer(badges, many=True).data,
            "xp_history": XPTransactionSerializer(history, many=True).data,
        })


class LeaderboardView(APIView):
    def get(self, request):
        top = (
            UserXP.objects.select_related("user")
            .filter(user__is_staff=False)
            .order_by("-total_xp")[:20]
        )
        data = []
        for rank, entry in enumerate(top, start=1):
            avatar_url = None
            if entry.user.avatar:
                avatar_url = request.build_absolute_uri(entry.user.avatar.url)
            data.append({
                "rank": rank,
                "first_name": entry.user.first_name,
                "last_name": entry.user.last_name,
                "avatar_url": avatar_url,
                "total_xp": entry.total_xp,
                "level": entry.level,
            })
        return Response(LeaderboardEntrySerializer(data, many=True).data)


class AnalyticsView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        students = User.objects.filter(is_staff=False)
        total_users = students.count()
        total_courses = Course.objects.count()
        total_lessons = Lesson.objects.count()
        total_quizzes = Quiz.objects.count()

        completed_lessons = LessonProgress.objects.filter(
            is_completed=True, user__is_staff=False
        ).count()
        videos_watched = LessonProgress.objects.filter(
            video_watched=True, user__is_staff=False
        ).count()
        quizzes_passed = QuizResult.objects.filter(passed=True, user__is_staff=False).count()
        quizzes_failed = QuizResult.objects.filter(passed=False, user__is_staff=False).count()

        avg_quiz_score = (
            QuizResult.objects.filter(user__is_staff=False).aggregate(avg=Avg("score"))["avg"]
            or 0
        )

        top_courses = (
            Course.objects.annotate(
                completions=Count(
                    "modules__lessons__lessonprogress",
                    filter=Q(
                        modules__lessons__lessonprogress__is_completed=True,
                        modules__lessons__lessonprogress__user__is_staff=False,
                    ),
                )
            )
            .order_by("-completions")[:5]
            .values("id", "title", "completions")
        )

        active_users = (
            LessonProgress.objects.filter(user__is_staff=False)
            .values("user")
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


class PaymentAnalyticsView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        student_transactions = Transaction.objects.filter(wallet__user__is_staff=False)
        topups = student_transactions.filter(type="topup")
        purchases = student_transactions.filter(type="purchase")
        renewals = student_transactions.filter(type="renewal")
        debits = student_transactions.filter(amount__lt=0)

        total_topped_up = topups.aggregate(total=Sum("amount"))["total"] or 0
        total_spent = abs(debits.aggregate(total=Sum("amount"))["total"] or 0)
        purchase_revenue = abs(purchases.aggregate(total=Sum("amount"))["total"] or 0)
        renewal_revenue = abs(renewals.aggregate(total=Sum("amount"))["total"] or 0)
        avg_transaction_amount = student_transactions.aggregate(avg=Avg("amount"))["avg"] or 0

        daily_revenue = (
            debits.annotate(day=TruncDate("created_at"))
            .values("day")
            .annotate(amount=Sum("amount"))
            .order_by("-day")[:14]
        )
        daily_revenue = [
            {"day": str(r["day"]), "amount": str(abs(r["amount"] or 0))}
            for r in daily_revenue
        ]

        top_spenders = (
            debits.values("wallet__user__id", "wallet__user__first_name", "wallet__user__last_name")
            .annotate(spent=Sum("amount"))
            .order_by("spent")[:5]
        )
        top_spenders = [
            {
                "user_id": r["wallet__user__id"],
                "first_name": r["wallet__user__first_name"],
                "last_name": r["wallet__user__last_name"],
                "spent": str(abs(r["spent"] or 0)),
            }
            for r in top_spenders
        ]

        tx_type_labels = dict(Transaction._meta.get_field("type").choices)
        transactions = student_transactions.select_related("wallet__user").order_by("-created_at")[:100]
        transactions_data = [
            {
                "id": t.id,
                "user_id": t.wallet.user_id,
                "first_name": t.wallet.user.first_name,
                "last_name": t.wallet.user.last_name,
                "phone": t.wallet.user.phone,
                "amount": str(t.amount),
                "type": t.type,
                "type_label": tx_type_labels.get(t.type, t.type),
                "description": t.description,
                "created_at": t.created_at.isoformat(),
            }
            for t in transactions
        ]

        return Response({
            "payments": {
                "transactions_total": student_transactions.count(),
                "topups_count": topups.count(),
                "purchases_count": purchases.count(),
                "renewals_count": renewals.count(),
                "total_topped_up": str(round(total_topped_up, 2)),
                "total_spent": str(round(total_spent, 2)),
                "purchase_revenue": str(round(purchase_revenue, 2)),
                "renewal_revenue": str(round(renewal_revenue, 2)),
                "avg_transaction_amount": str(round(abs(avg_transaction_amount), 2)),
                "max_transaction": str(
                    round(
                        abs(student_transactions.aggregate(v=Max("amount"))["v"] or 0),
                        2,
                    )
                ),
                "min_transaction": str(
                    round(
                        abs(student_transactions.aggregate(v=Min("amount"))["v"] or 0),
                        2,
                    )
                ),
                "daily_revenue": daily_revenue,
                "top_spenders": top_spenders,
            },
            "transactions": transactions_data,
        })

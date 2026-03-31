from datetime import datetime, time, timedelta

from django.db.models import Avg, Count, Max, Min, Q, Sum
from django.db.models.functions import Coalesce
from django.db.models.functions import TruncDate
from django.utils import timezone

from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from django.shortcuts import get_object_or_404

from apps.courses.models import Course
from apps.lessons.models import Lesson
from apps.progress.models import LessonProgress, QuizResult
from apps.quizzes.models import Quiz
from apps.users.models import Transaction, User

from .models import Badge, UserXP, XPTransaction
from .xp_utils import reconcile_user_xp_from_history
from .serializers import (
    BadgeSerializer,
    LeaderboardEntrySerializer,
    UserXPSerializer,
    XPTransactionSerializer,
)


def _resolve_period(request):
    """
    Supported:
    - ?period=10d | 1m | 6m | all
    - ?period=custom&start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
    """
    now = timezone.now()
    period = (request.query_params.get("period") or "all").strip().lower()

    if period == "10d":
        return now - timedelta(days=10), now, "10d"
    if period == "1m":
        return now - timedelta(days=30), now, "1m"
    if period == "6m":
        return now - timedelta(days=180), now, "6m"
    if period == "custom":
        start_raw = (request.query_params.get("start_date") or "").strip()
        end_raw = (request.query_params.get("end_date") or "").strip()
        if not start_raw or not end_raw:
            return None, None, "all"
        try:
            start_d = datetime.strptime(start_raw, "%Y-%m-%d").date()
            end_d = datetime.strptime(end_raw, "%Y-%m-%d").date()
        except ValueError:
            return None, None, "all"
        if start_d > end_d:
            start_d, end_d = end_d, start_d
        start_dt = timezone.make_aware(datetime.combine(start_d, time.min))
        end_dt = timezone.make_aware(datetime.combine(end_d, time.max))
        return start_dt, end_dt, "custom"
    return None, None, "all"


class ProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        xp, _ = UserXP.objects.get_or_create(user=request.user)
        if not request.user.is_staff:
            reconcile_user_xp_from_history(request.user)
            xp.refresh_from_db()
        badges = Badge.objects.filter(user=request.user).order_by("-earned_at")
        # Staff do not see XP history.
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
        top_users = (
            User.objects.filter(is_staff=False)
            .annotate(xp_sum=Coalesce(Sum("xp_transactions__amount"), 0))
            .order_by("-xp_sum", "id")[:20]
        )
        data = []
        for rank, u in enumerate(top_users, start=1):
            avatar_url = None
            if u.avatar:
                avatar_url = request.build_absolute_uri(u.avatar.url)
            total = int(u.xp_sum)
            level = (total // 100) + 1 if total > 0 else 1
            data.append({
                "user_id": u.id,
                "rank": rank,
                "first_name": u.first_name,
                "last_name": u.last_name,
                "avatar_url": avatar_url,
                "total_xp": total,
                "level": level,
            })
        return Response(LeaderboardEntrySerializer(data, many=True).data)


class LeaderboardUserDetailView(APIView):
    """
    Public XP breakdown for a learner (non-staff). Any authenticated user may view.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request, user_id):
        target = get_object_or_404(User, pk=user_id, is_staff=False, is_active=True)
        reconcile_user_xp_from_history(target)
        xp, _ = UserXP.objects.get_or_create(user=target)
        xp.refresh_from_db()
        total = int(
            XPTransaction.objects.filter(user=target).aggregate(s=Sum("amount"))["s"] or 0
        )
        level = (total // 100) + 1 if total > 0 else 1
        history = XPTransaction.objects.filter(user=target).order_by("-created_at")[:200]
        badges = Badge.objects.filter(user=target).order_by("-earned_at")
        avatar_url = None
        if target.avatar:
            avatar_url = request.build_absolute_uri(target.avatar.url)
        return Response(
            {
                "user": {
                    "id": target.id,
                    "first_name": target.first_name,
                    "last_name": target.last_name,
                    "avatar_url": avatar_url,
                },
                "total_xp": total,
                "level": level,
                "current_streak": xp.current_streak,
                "best_streak": xp.best_streak,
                "xp_history": XPTransactionSerializer(history, many=True).data,
                "badges": BadgeSerializer(badges, many=True).data,
            }
        )


class AnalyticsView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        start_dt, end_dt, period_code = _resolve_period(request)
        students = User.objects.filter(is_staff=False)
        if start_dt and end_dt:
            students = students.filter(date_joined__range=(start_dt, end_dt))
        total_users = students.count()
        total_courses = Course.objects.count()
        total_lessons = Lesson.objects.count()
        total_quizzes = Quiz.objects.count()

        lesson_progress_qs = LessonProgress.objects.filter(
            is_completed=True, user__is_staff=False
        )
        quiz_results_qs = QuizResult.objects.filter(user__is_staff=False)
        if start_dt and end_dt:
            lesson_progress_qs = lesson_progress_qs.filter(completed_at__range=(start_dt, end_dt))
            quiz_results_qs = quiz_results_qs.filter(completed_at__range=(start_dt, end_dt))

        completed_lessons = lesson_progress_qs.count()
        videos_watched = LessonProgress.objects.filter(
            video_watched=True, user__is_staff=False
        )
        if start_dt and end_dt:
            videos_watched = videos_watched.filter(completed_at__range=(start_dt, end_dt))
        videos_watched = videos_watched.count()

        quizzes_passed = quiz_results_qs.filter(passed=True).count()
        quizzes_failed = quiz_results_qs.filter(passed=False).count()

        avg_quiz_score = (
            quiz_results_qs.aggregate(avg=Avg("score"))["avg"]
            or 0
        )

        top_courses = (
            Course.objects.annotate(
                completions=Count(
                    "modules__lessons__lessonprogress",
                    filter=Q(
                        modules__lessons__lessonprogress__is_completed=True,
                        modules__lessons__lessonprogress__user__is_staff=False,
                        **(
                            {
                                "modules__lessons__lessonprogress__completed_at__range": (
                                    start_dt,
                                    end_dt,
                                )
                            }
                            if start_dt and end_dt
                            else {}
                        ),
                    ),
                )
            )
            .order_by("-completions")[:5]
            .values("id", "title", "completions")
        )

        active_users_qs = LessonProgress.objects.filter(user__is_staff=False)
        if start_dt and end_dt:
            active_users_qs = active_users_qs.filter(completed_at__range=(start_dt, end_dt))
        active_users = active_users_qs.values("user").distinct().count()

        return Response({
            "period": {
                "code": period_code,
                "start": start_dt.isoformat() if start_dt else None,
                "end": end_dt.isoformat() if end_dt else None,
            },
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
        start_dt, end_dt, period_code = _resolve_period(request)
        student_transactions = Transaction.objects.filter(wallet__user__is_staff=False)
        if start_dt and end_dt:
            student_transactions = student_transactions.filter(created_at__range=(start_dt, end_dt))
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
            "period": {
                "code": period_code,
                "start": start_dt.isoformat() if start_dt else None,
                "end": end_dt.isoformat() if end_dt else None,
            },
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

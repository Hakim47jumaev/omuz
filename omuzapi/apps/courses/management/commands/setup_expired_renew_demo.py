"""
Attach one expired paid subscription to +992901000002 for renew-flow testing.

Does not wipe the database. Picks the first paid course by id (same as reseed_omuz paid[0]).

Usage:
  python manage.py setup_expired_renew_demo
"""

from datetime import timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.db.models import Sum
from django.utils import timezone

from apps.courses.models import Course, CourseReview, Subscription
from apps.lessons.models import Lesson
from apps.progress.models import LessonProgress, QuizAttempt, QuizResult
from apps.quizzes.models import Quiz
from apps.users.models import Transaction, User

DEMO_EXPIRED_SUB_PHONE = "+992901000002"


def _normalize_phone(raw: str) -> str:
    digits = "".join(ch for ch in (raw or "") if ch.isdigit())
    return f"+{digits}" if digits else (raw or "").strip()


class Command(BaseCommand):
    help = "Set +992901000002 to one expired subscription on first paid course (renew demo)."

    def handle(self, *args, **options):
        phone = _normalize_phone(DEMO_EXPIRED_SUB_PHONE)
        u = User.objects.filter(phone=phone).first()
        if not u:
            self.stderr.write(self.style.ERROR(f"User {phone} not found."))
            return

        course = Course.objects.filter(is_published=True, price__gt=0).order_by("id").first()
        if not course:
            self.stderr.write(self.style.ERROR("No paid published courses."))
            return

        now = timezone.now()
        starts = now - timedelta(days=45)
        expires = now - timedelta(days=6)

        Subscription.objects.filter(user=u).delete()
        Subscription.objects.create(
            user=u,
            course=course,
            starts_at=starts,
            expires_at=expires,
            is_first=True,
        )

        LessonProgress.objects.filter(user=u).exclude(lesson__module__course=course).delete()
        QuizResult.objects.filter(user=u).exclude(quiz__lesson__module__course=course).delete()
        QuizAttempt.objects.filter(user=u).exclude(quiz__lesson__module__course=course).delete()
        CourseReview.objects.filter(user=u).exclude(course=course).delete()

        cost = course.price
        if hasattr(u, "wallet"):
            Transaction.objects.filter(wallet=u.wallet, type="purchase").delete()
            Transaction.objects.create(
                wallet=u.wallet,
                amount=-cost,
                type="purchase",
                description=f"Wallet debit: subscription to «{course.title}» for 1 month ({cost} TJS)"[
                    :255
                ],
            )
            total = Transaction.objects.filter(wallet=u.wallet).aggregate(s=Sum("amount"))["s"]
            total = total if total is not None else Decimal("0")
            u.wallet.balance = max(Decimal("0"), total)
            u.wallet.save(update_fields=["balance"])

        if not LessonProgress.objects.filter(
            user=u, lesson__module__course=course, is_completed=True
        ).exists():
            first_lesson = (
                Lesson.objects.filter(module__course=course)
                .order_by("module__order", "order")
                .first()
            )
            if first_lesson:
                qz = Quiz.objects.filter(lesson=first_lesson).first()
                has_quiz = qz is not None
                LessonProgress.objects.update_or_create(
                    user=u,
                    lesson=first_lesson,
                    defaults={
                        "video_watched": True,
                        "quiz_passed": True if has_quiz else False,
                        "quiz_score": 88 if has_quiz else 0,
                        "is_completed": True,
                        "completed_at": now - timedelta(days=12),
                    },
                )
                if has_quiz and qz is not None:
                    QuizResult.objects.update_or_create(
                        user=u, quiz=qz, defaults={"score": 88, "passed": True}
                    )
                    QuizAttempt.objects.filter(user=u, quiz=qz).delete()
                    QuizAttempt.objects.create(
                        user=u,
                        quiz=qz,
                        attempt_no=1,
                        score=88,
                        passed=True,
                        xp_awarded=20,
                    )

        self.stdout.write(
            self.style.SUCCESS(
                f"{phone}: one expired sub on «{course.title}» (id={course.id}), "
                f"expires_at={expires.date()} — open this course in the app and use Renew."
            )
        )

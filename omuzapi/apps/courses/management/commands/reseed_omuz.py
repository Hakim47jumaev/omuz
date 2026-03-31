"""
Wipe the database and seed a full educational platform dataset.

- Admin: phone +992985349808 (is_staff + is_superuser)
- Student +992901000002 (Nigina Saidova): exactly one paid course, subscription already expired — for testing renew.
- ~20 students with wallets, varied course subscriptions
- Courses → modules → lessons (duration, descriptions, embed-safe YouTube rotation)
- Quiz per lesson (3–5 simple questions)
- Course reviews from multiple users
- Transactions (top-ups + course purchases) over the last ~12 months

Usage:
  python manage.py reseed_omuz
"""

from __future__ import annotations

import random
from datetime import datetime, timedelta
from decimal import Decimal

from django.contrib.admin.models import LogEntry
from django.core.management.base import BaseCommand
from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from apps.courses.management.commands.platform_seed_data import build_all_courses, categories_rows
from apps.courses.models import Category, Course, CourseReview, GlobalDiscount, Module, Subscription
from apps.gamification.models import Badge, UserXP, XPTransaction
from apps.gamification.xp_utils import reconcile_user_xp_from_history
from apps.lessons.models import Lesson
from apps.progress.models import LessonProgress, QuizAttempt, QuizResult
from apps.quizzes.models import Answer, Question, Quiz
from apps.users.models import DeviceToken, Notification, Resume, Transaction, User, Wallet

YT = "https://www.youtube.com/watch?v={}"

# Public YouTube tutorials (standard watch URLs; embedding allowed for typical uploads).
_YT_ROTATION = [
    "x7X9w_GIm1s",
    "YYXdXT2l-Gg",
    "kqtD5dpn9C8",
    "rHux0gMZ3Eg",
    "W6NZfCO5SIk",
    "UB1O30fR-EE",
    "1PnVor36_40",
    "Vl0H-qTcmOg",
    "Hp9gwnNvZ4Y",
    "nUubjPL8jfo",
    "FTFaQWZBqQ8",
    "ad79nYk2keg",
    "502G7Kl7RFU",
    "inWWhr5tnEA",
    "4RixMPF4xis",
    "r-uOL6NUw5A",
    "x7X9w_GIm1s",
    "YYXdXT2l-Gg",
    "kqtD5dpn9C8",
    "rHux0gMZ3Eg",
    "W6NZfCO5SIk",
    "UB1O30fR-EE",
    "1PnVor36_40",
    "Vl0H-qTcmOg",
    "Hp9gwnNvZ4Y",
    "nUubjPL8jfo",
    "FTFaQWZBqQ8",
    "ad79nYk2keg",
    "502G7Kl7RFU",
    "inWWhr5tnEA",
    "4RixMPF4xis",
    "r-uOL6NUw5A",
]


def _normalize_phone(raw: str) -> str:
    digits = "".join(ch for ch in (raw or "") if ch.isdigit())
    return f"+{digits}" if digits else (raw or "").strip()


def _assign_rotation_videos(payload: list[dict]) -> None:
    i = 0
    for spec in payload:
        for mod in spec["modules"]:
            for les in mod["lessons"]:
                les["video_url"] = YT.format(_YT_ROTATION[i % len(_YT_ROTATION)])
                i += 1


STUDENTS: list[tuple[str, str, str]] = [
    ("+992901000001", "Faridun", "Karimov"),
    ("+992901000002", "Nigina", "Saidova"),
    ("+992901000003", "Rustam", "Azizov"),
    ("+992901000004", "Madina", "Rahimova"),
    ("+992901000005", "Shahrom", "Nematov"),
    ("+992901000006", "Parvina", "Qodirova"),
    ("+992901000007", "Jamshed", "Usmonov"),
    ("+992901000008", "Gulnoza", "Mirzoeva"),
    ("+992901000009", "Behruz", "Safarov"),
    ("+992901000010", "Zarina", "Alimova"),
    ("+992901000011", "Komron", "Fayzulloev"),
    ("+992901000012", "Dilbar", "Hoshimova"),
    ("+992901000013", "Suhrob", "Tolibov"),
    ("+992901000014", "Mehrangez", "Bobojonova"),
    ("+992901000015", "Firdavs", "Shodmonov"),
    ("+992901000016", "Nodira", "Yusupova"),
    ("+992901000017", "Azam", "Rahmonov"),
    ("+992901000018", "Lola", "Sharipova"),
    ("+992901000019", "Khurshed", "Nabiev"),
    ("+992901000020", "Amina", "Qurbonova"),
]

ADMIN_PHONE = "+992985349808"


class Command(BaseCommand):
    help = "Full DB reset + seed (admin, 20 students, courses, quizzes, reviews, transactions)."

    @transaction.atomic
    def handle(self, *args, **options):
        self._wipe_everything()

        admin = User.objects.create(
            phone=_normalize_phone(ADMIN_PHONE),
            first_name="Platform",
            last_name="Administrator",
            is_staff=True,
            is_superuser=True,
            is_active=True,
        )
        self.stdout.write(self.style.SUCCESS(f"Admin user: {admin.phone} (staff)"))

        students: list[User] = []
        for phone, fn, ln in STUDENTS:
            students.append(
                User.objects.create(
                    phone=phone,
                    first_name=fn,
                    last_name=ln,
                    is_staff=False,
                    is_active=True,
                )
            )

        categories = self._seed_categories()
        payload = build_all_courses()
        _assign_rotation_videos(payload)
        courses = self._seed_courses(categories, payload)
        self.stdout.write(self.style.SUCCESS(f"Courses: {len(courses)}"))

        paid = [c for c in courses if c.price > 0]
        now = timezone.now()
        rng = random.Random(20260331)

        subs_records: list[tuple[User, Course, datetime]] = []

        demo_phone_norm = _normalize_phone(DEMO_EXPIRED_SUB_PHONE)

        for u in students:
            if u.phone == demo_phone_norm:
                continue
            n_sub = rng.randint(2, min(len(courses), 6))
            pick = rng.sample(courses, n_sub)
            for course in pick:
                starts = now - timedelta(days=rng.randint(10, 340))
                # Remaining access: 1–30 days from now (matches live purchase = 30d max single period).
                expires = now + timedelta(days=rng.randint(1, 30))
                Subscription.objects.create(
                    user=u,
                    course=course,
                    starts_at=starts,
                    expires_at=expires,
                    is_first=True,
                )
                if course in paid:
                    subs_records.append((u, course, starts))

        if paid:
            demo_u = next((s for s in students if s.phone == demo_phone_norm), None)
            if demo_u:
                exp_course = paid[0]
                starts = now - timedelta(days=45)
                expires = now - timedelta(days=6)
                Subscription.objects.create(
                    user=demo_u,
                    course=exp_course,
                    starts_at=starts,
                    expires_at=expires,
                    is_first=True,
                )
                subs_records.append((demo_u, exp_course, starts))
                self.stdout.write(
                    self.style.SUCCESS(
                        f"Renew demo: {demo_u.phone} — «{exp_course.title}» "
                        f"(expired {expires.date()}, renew in app)"
                    )
                )

        self._seed_purchase_transactions(subs_records, rng, now)
        self._seed_misc_transactions(students, paid, rng, now)
        for u in students:
            self._sync_wallet_balance(u)

        self._seed_course_reviews(students, courses, rng)
        self._seed_xp(students, rng)
        self._seed_progress(students, rng, now)
        self._trim_demo_user_to_single_expired_course(paid, now)

        self.stdout.write(
            self.style.SUCCESS(
                f"Done. Users: {User.objects.count()} (1 admin + {len(students)} students)."
            )
        )

    def _trim_demo_user_to_single_expired_course(self, paid: list[Course], now):
        """Keep +992901000002 progress/reviews only on the one demo paid course."""
        if not paid:
            return
        phone = _normalize_phone(DEMO_EXPIRED_SUB_PHONE)
        u = User.objects.filter(phone=phone).first()
        if not u:
            return
        course = paid[0]
        LessonProgress.objects.filter(user=u).exclude(lesson__module__course=course).delete()
        QuizResult.objects.filter(user=u).exclude(quiz__lesson__module__course=course).delete()
        QuizAttempt.objects.filter(user=u).exclude(quiz__lesson__module__course=course).delete()
        CourseReview.objects.filter(user=u).exclude(course=course).delete()

        has_completed = LessonProgress.objects.filter(
            user=u, lesson__module__course=course, is_completed=True
        ).exists()
        if has_completed:
            return

        first_lesson = (
            Lesson.objects.filter(module__course=course)
            .select_related("module")
            .order_by("module__order", "order")
            .first()
        )
        if first_lesson is None:
            return
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
                user=u,
                quiz=qz,
                defaults={"score": 88, "passed": True},
            )
            QuizAttempt.objects.create(
                user=u,
                quiz=qz,
                attempt_no=1,
                score=88,
                passed=True,
                xp_awarded=20,
            )

    def _wipe_everything(self):
        QuizAttempt.objects.all().delete()
        QuizResult.objects.all().delete()
        LessonProgress.objects.all().delete()
        Answer.objects.all().delete()
        Question.objects.all().delete()
        Quiz.objects.all().delete()
        Lesson.objects.all().delete()
        Module.objects.all().delete()
        Subscription.objects.all().delete()
        CourseReview.objects.all().delete()
        for gd in GlobalDiscount.objects.all():
            gd.target_courses.clear()
        GlobalDiscount.objects.all().delete()
        Course.objects.all().delete()
        Category.objects.all().delete()

        Transaction.objects.all().delete()
        Notification.objects.all().delete()
        DeviceToken.objects.all().delete()
        Resume.objects.all().delete()
        Badge.objects.all().delete()
        XPTransaction.objects.all().delete()
        UserXP.objects.all().delete()

        try:
            LogEntry.objects.all().delete()
        except Exception:
            pass

        Wallet.objects.all().delete()
        User.objects.all().delete()

    def _seed_categories(self) -> dict[str, Category]:
        return {name: Category.objects.create(name=name, icon=icon) for name, icon in categories_rows()}

    def _seed_courses(self, categories: dict[str, Category], payload: list[dict]) -> list[Course]:
        courses: list[Course] = []
        for spec in payload:
            cat = categories[spec["category"]]
            c = Course.objects.create(
                title=spec["title"],
                description=spec["description"],
                category=cat,
                image=spec["image"],
                preview_video_url=spec["preview_video_url"],
                price=spec["price"],
                is_published=True,
            )
            courses.append(c)
            for mi, mod in enumerate(spec["modules"]):
                m = Module.objects.create(course=c, title=mod["title"], order=mi)
                for li, les in enumerate(mod["lessons"]):
                    lesson = Lesson.objects.create(
                        module=m,
                        title=les["title"],
                        description=les["description"],
                        video_url=les["video_url"],
                        duration_minutes=les.get("duration_minutes", 15),
                        order=li,
                    )
                    quiz = Quiz.objects.create(
                        lesson=lesson,
                        title=les.get("quiz_title") or f"{les['title']} — quiz",
                    )
                    for qi, qd in enumerate(les["questions"]):
                        q = Question.objects.create(quiz=quiz, text=qd["text"], order=qi)
                        for ans in qd["answers"]:
                            Answer.objects.create(
                                question=q, text=ans["text"], is_correct=ans["is_correct"]
                            )
        return courses

    def _seed_purchase_transactions(
        self,
        subs_records: list[tuple[User, Course, datetime]],
        rng: random.Random,
        now,
    ):
        """Purchase debits aligned with subscriptions, timestamps within last 12 months."""
        for u, course, starts in subs_records:
            if not hasattr(u, "wallet"):
                continue
            cost = course.price
            desc = f"Wallet debit: subscription to «{course.title}» for 1 month ({cost} TJS)"
            t = Transaction.objects.create(
                wallet=u.wallet,
                amount=-cost,
                type="purchase",
                description=desc[:255],
            )
            days_ago = min(365, max(1, (now - starts).days + rng.randint(0, 5)))
            Transaction.objects.filter(pk=t.pk).update(created_at=now - timedelta(days=days_ago))

    def _seed_misc_transactions(self, students: list[User], paid: list[Course], rng: random.Random, now):
        demo_phone_norm = _normalize_phone(DEMO_EXPIRED_SUB_PHONE)
        for u in students:
            if u.phone == demo_phone_norm:
                continue
            if not hasattr(u, "wallet"):
                continue
            for _ in range(rng.randint(4, 10)):
                days_ago = rng.randint(0, 364)
                created_at = now - timedelta(
                    days=days_ago, hours=rng.randint(0, 23), minutes=rng.randint(0, 59)
                )
                if rng.random() < 0.5:
                    amt = Decimal(str(rng.choice([25, 40, 75, 100, 150, 250, 400])))
                    t = Transaction.objects.create(
                        wallet=u.wallet,
                        amount=amt,
                        type="topup",
                        description=rng.choice(
                            [
                                "Card top-up",
                                "Mobile payment — wallet",
                                "Balance credit",
                                "Promotional credit",
                            ]
                        ),
                    )
                else:
                    if not paid:
                        continue
                    course = rng.choice(paid)
                    days = rng.choice([1, 5, 10])
                    base = (course.price / Decimal(30) * Decimal(days)).quantize(Decimal("0.01"))
                    t = Transaction.objects.create(
                        wallet=u.wallet,
                        amount=-base,
                        type="renewal",
                        description=f"Renewal: {course.title[:50]}",
                    )
                Transaction.objects.filter(pk=t.pk).update(created_at=created_at)

    def _sync_wallet_balance(self, user: User):
        if user.is_staff or not hasattr(user, "wallet"):
            return
        w = user.wallet
        total = Transaction.objects.filter(wallet=w).aggregate(s=Sum("amount"))["s"] or Decimal("0")
        if total < 0:
            adj = (-total + Decimal(str(random.randint(100, 450)))).quantize(Decimal("0.01"))
            t = Transaction.objects.create(
                wallet=w,
                amount=adj,
                type="topup",
                description="Opening balance adjustment",
            )
            Transaction.objects.filter(pk=t.pk).update(
                created_at=timezone.now() - timedelta(days=random.randint(200, 360))
            )
            total = Transaction.objects.filter(wallet=w).aggregate(s=Sum("amount"))["s"] or Decimal("0")
        w.balance = max(Decimal("0"), total)
        w.save(update_fields=["balance"])

    def _seed_course_reviews(self, students: list[User], courses: list[Course], rng: random.Random):
        pairs: set[tuple[int, int]] = set()
        for u in students:
            subscribed_ids = set(
                Subscription.objects.filter(user=u).values_list("course_id", flat=True)
            )
            for cid in subscribed_ids:
                if rng.random() < 0.72:
                    stars = rng.choices([3, 4, 5], weights=[1, 3, 4])[0]
                    CourseReview.objects.update_or_create(
                        user=u,
                        course_id=cid,
                        defaults={"stars": stars},
                    )
                    pairs.add((u.id, cid))
        for _ in range(35):
            u = rng.choice(students)
            c = rng.choice(courses)
            if (u.id, c.id) in pairs:
                continue
            if not Subscription.objects.filter(user=u, course=c).exists():
                continue
            stars = rng.choices([3, 4, 5], weights=[1, 2, 4])[0]
            CourseReview.objects.update_or_create(
                user=u, course=c, defaults={"stars": stars}
            )
            pairs.add((u.id, c.id))

    def _seed_xp(self, students: list[User], rng: random.Random):
        def _reason():
            k = rng.randint(0, 4)
            if k == 0:
                return f"Lesson {rng.randint(1, 200)} completed"
            if k == 1:
                return f"Daily streak bonus (day {rng.randint(1, 14)})"
            if k == 2:
                return f"Quiz {rng.randint(1, 200)} passed (attempt {rng.randint(1, 3)})"
            if k == 3:
                return f"High-score bonus for quiz {rng.randint(1, 200)}"
            return f"Perfect score bonus for quiz {rng.randint(1, 200)}"

        for u in students:
            xp, _ = UserXP.objects.get_or_create(user=u)
            xp.current_streak = rng.randint(0, 14)
            xp.best_streak = max(xp.current_streak, rng.randint(0, 25))
            xp.save(update_fields=["current_streak", "best_streak"])
            for _ in range(rng.randint(6, 14)):
                xpt = XPTransaction.objects.create(
                    user=u,
                    amount=rng.randint(8, 95),
                    reason=_reason(),
                )
                XPTransaction.objects.filter(pk=xpt.pk).update(
                    created_at=timezone.now() - timedelta(days=rng.randint(0, 360))
                )
            reconcile_user_xp_from_history(u)

    def _seed_progress(self, students: list[User], rng: random.Random, now):
        lessons = list(Lesson.objects.select_related("module__course").all())
        if not lessons:
            return
        progress_rows: list[LessonProgress] = []
        quiz_results: list[QuizResult] = []
        quiz_attempts: list[QuizAttempt] = []
        for u in students:
            k = rng.randint(4, min(22, len(lessons)))
            for lesson in rng.sample(lessons, k):
                has_quiz = hasattr(lesson, "quiz")
                passed = rng.random() > 0.12 if has_quiz else True
                score = rng.randint(72, 100) if passed else rng.randint(35, 70)
                days_ago = rng.randint(1, 300)
                completed_at = now - timedelta(days=days_ago) if (passed or not has_quiz) else None
                is_done = passed if has_quiz else True
                progress_rows.append(
                    LessonProgress(
                        user=u,
                        lesson=lesson,
                        video_watched=True,
                        quiz_passed=passed if has_quiz else False,
                        quiz_score=score if has_quiz else 0,
                        is_completed=is_done,
                        completed_at=completed_at if is_done else None,
                    )
                )
                if has_quiz and passed:
                    qz = lesson.quiz
                    qr = QuizResult(user=u, quiz=qz, score=score, passed=True)
                    quiz_results.append((qr, completed_at))
                    quiz_attempts.append(
                        (
                            QuizAttempt(
                                user=u,
                                quiz=qz,
                                attempt_no=1,
                                score=score,
                                passed=True,
                                xp_awarded=rng.randint(12, 45),
                            ),
                            completed_at,
                        )
                    )
        LessonProgress.objects.bulk_create(progress_rows, batch_size=400)
        for qr, completed_at in quiz_results:
            qr.save()
            if completed_at:
                QuizResult.objects.filter(pk=qr.pk).update(completed_at=completed_at)
        for att, completed_at in quiz_attempts:
            att.save()
            if completed_at:
                QuizAttempt.objects.filter(pk=att.pk).update(submitted_at=completed_at)

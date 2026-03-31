import re
from datetime import timedelta
from decimal import Decimal

from django.db.models import Avg, Count, Exists, OuterRef, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.generics import ListAPIView, RetrieveAPIView
from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.viewsets import ModelViewSet

from apps.gamification.models import XPTransaction
from apps.lessons.models import Lesson
from apps.progress.models import LessonProgress
from apps.quizzes.models import Quiz
from apps.users.models import Notification, Transaction, User
from apps.users.push import send_push_to_user
from .models import Category, Course, CourseReview, GlobalDiscount, Module, Subscription
from .serializers import (
    AdminCategorySerializer,
    AdminCourseSerializer,
    GlobalDiscountSerializer,
    AdminModuleSerializer,
    CategorySerializer,
    CourseDetailSerializer,
    CourseListSerializer,
    PromotionCourseSerializer,
)


class CategoryListView(ListAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer


def _courses_with_rating_qs(base):
    return base.annotate(
        rating_avg=Avg("reviews__stars"),
        rating_count=Count("reviews", distinct=True),
    )


class CourseListView(ListAPIView):
    serializer_class = CourseListSerializer

    def get_queryset(self):
        qs = Course.objects.filter(is_published=True).select_related("category")
        category_id = self.request.query_params.get("category")
        if category_id:
            qs = qs.filter(category_id=category_id)
        return _courses_with_rating_qs(qs)


class CourseDetailView(RetrieveAPIView):
    queryset = _courses_with_rating_qs(
        Course.objects.prefetch_related("modules__lessons").select_related("category")
    )
    serializer_class = CourseDetailSerializer
    permission_classes = [IsAuthenticated]

    def retrieve(self, request, *args, **kwargs):
        course = self.get_object()

        # Staff and free courses see full content.
        if request.user.is_staff or course.is_free:
            return Response(self.get_serializer(course).data)

        has_active = Subscription.objects.filter(
            user=request.user,
            course=course,
            expires_at__gt=timezone.now(),
        ).exists()

        data = self.get_serializer(course).data
        if not has_active:
            # Without an active subscription, only description/preview; no modules/lessons.
            data["modules"] = []
            data["locked"] = True
            data["locked_reason"] = "subscription_required"
        else:
            data["locked"] = False

        return Response(data)


class CourseReviewView(APIView):
    """POST: set or update a 1–5 star rating (not for staff)."""

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        if request.user.is_staff:
            return Response(
                {"detail": "Staff cannot submit course ratings."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        course = get_object_or_404(Course, pk=pk, is_published=True)
        raw = request.data.get("stars")
        try:
            stars = int(raw)
        except (TypeError, ValueError):
            return Response(
                {"detail": "Send stars as an integer from 1 to 5."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if stars < 1 or stars > 5:
            return Response(
                {"detail": "stars must be between 1 and 5."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not course.is_free:
            has_access = Subscription.objects.filter(
                user=request.user,
                course=course,
                expires_at__gt=timezone.now(),
            ).exists()
            if not has_access:
                return Response(
                    {
                        "detail": "Subscribe to this course before leaving a rating.",
                    },
                    status=status.HTTP_403_FORBIDDEN,
                )

        CourseReview.objects.update_or_create(
            user=request.user,
            course=course,
            defaults={"stars": stars},
        )
        agg = CourseReview.objects.filter(course=course).aggregate(
            avg=Avg("stars"),
            cnt=Count("id"),
        )
        return Response(
            {
                "stars": stars,
                "rating_avg": round(float(agg["avg"]), 2) if agg["avg"] is not None else None,
                "rating_count": agg["cnt"] or 0,
            }
        )


class ContinueLearningView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        courses = _continue_learning_courses(request.user)
        return Response(CourseListSerializer(courses, many=True).data)


def _continue_learning_courses(user):
    """
    Courses the user is allowed to keep learning now: free (price <= 0) or active subscription,
    and they have at least one completed lesson on that course.
    """
    completed_lesson_ids = set(
        LessonProgress.objects.filter(user=user, is_completed=True).values_list(
            "lesson_id", flat=True
        )
    )
    if not completed_lesson_ids:
        return Course.objects.none()
    course_ids = (
        Course.objects.filter(modules__lessons__id__in=completed_lesson_ids)
        .distinct()
        .values_list("id", flat=True)
    )
    now = timezone.now()
    has_active_sub = Subscription.objects.filter(
        user=user,
        course_id=OuterRef("pk"),
        expires_at__gt=now,
    )
    return _courses_with_rating_qs(
        Course.objects.filter(id__in=course_ids, is_published=True)
        .filter(Q(price__lte=0) | Exists(has_active_sub))
        .select_related("category")
    )


def _xp_totals_by_course(user, course_ids):
    """Attribute XP from lesson + quiz transactions to courses."""
    if not course_ids:
        return {}
    lesson_rows = Lesson.objects.filter(module__course_id__in=course_ids).values_list(
        "id", "module__course_id"
    )
    lesson_to_course = {}
    for lid, cid in lesson_rows:
        lesson_to_course[lid] = cid
    quiz_course = {}
    for qid, lid in Quiz.objects.filter(lesson_id__in=lesson_to_course.keys()).values_list(
        "id", "lesson_id"
    ):
        cid = lesson_to_course.get(lid)
        if cid:
            quiz_course[qid] = cid
    totals = {cid: 0 for cid in course_ids}
    for tx in XPTransaction.objects.filter(user=user).iterator(chunk_size=500):
        r = tx.reason or ""
        if r.startswith("Lesson ") and r.endswith(" completed"):
            try:
                lid = int(r[len("Lesson ") : -len(" completed")])
            except ValueError:
                continue
            cid = lesson_to_course.get(lid)
            if cid:
                totals[cid] = totals.get(cid, 0) + int(tx.amount)
            continue
        m = re.search(r"Quiz (\d+)", r)
        if m:
            qid = int(m.group(1))
            cid = quiz_course.get(qid)
            if cid:
                totals[cid] = totals.get(cid, 0) + int(tx.amount)
    return totals


def _my_courses_payload(request, user):
    course_ids = list(
        dict.fromkeys(
            Subscription.objects.filter(user=user).values_list("course_id", flat=True)
        )
    )
    if not course_ids:
        return []
    courses = {
        c.id: c
        for c in Course.objects.filter(id__in=course_ids, is_published=True).select_related(
            "category"
        )
    }
    now = timezone.now()
    xp_totals = _xp_totals_by_course(user, list(courses.keys()))
    out = []
    for cid in course_ids:
        c = courses.get(cid)
        if not c:
            continue
        total_lessons = Lesson.objects.filter(module__course_id=cid).count()
        completed = LessonProgress.objects.filter(
            user=user, lesson__module__course_id=cid, is_completed=True
        ).count()
        last_sub = (
            Subscription.objects.filter(user=user, course_id=cid)
            .order_by("-expires_at")
            .first()
        )
        out.append(
            {
                "id": c.id,
                "title": c.title,
                "image": c.image,
                "category": CategorySerializer(c.category).data,
                "lessons_total": total_lessons,
                "lessons_completed": completed,
                "xp_from_course": xp_totals.get(cid, 0),
                "subscription_active": last_sub.expires_at > now if last_sub else False,
                "expires_at": last_sub.expires_at.isoformat() if last_sub else None,
            }
        )
    out.sort(key=lambda x: (not x["subscription_active"], x["title"]))
    return out


class HomeFeedView(APIView):
    """Popular (top 5 by enrollments + rating), recommendations, continue, my courses."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        now = timezone.now()
        published = Course.objects.filter(is_published=True)

        popular_qs = _courses_with_rating_qs(
            published.annotate(enroll_count=Count("subscriptions__user", distinct=True))
        ).order_by("-enroll_count", "-rating_avg", "-rating_count", "-id")[:5]
        popular = CourseListSerializer(popular_qs, many=True).data

        if request.user.is_staff:
            return Response(
                {
                    "popular": popular,
                    "for_you": [],
                    "continue": [],
                    "my_courses": [],
                }
            )

        sub_cats = list(
            Subscription.objects.filter(user=request.user).values_list(
                "course__category_id", flat=True
            )
        )
        prog_cats = list(
            Course.objects.filter(
                modules__lessons__lessonprogress__user=request.user,
                modules__lessons__lessonprogress__is_completed=True,
            )
            .values_list("category_id", flat=True)
            .distinct()
        )
        cat_ids = list(set(sub_cats) | set(prog_cats))
        active_course_ids = set(
            Subscription.objects.filter(user=request.user, expires_at__gt=now).values_list(
                "course_id", flat=True
            )
        )

        if cat_ids:
            fy_qs = _courses_with_rating_qs(
                published.filter(category_id__in=cat_ids).exclude(id__in=active_course_ids)
            ).order_by("-rating_avg", "-rating_count", "-id")[:8]
        else:
            fy_qs = _courses_with_rating_qs(
                published.exclude(id__in=active_course_ids).order_by("-rating_avg", "-id")[:5]
            )
        for_you = CourseListSerializer(fy_qs, many=True).data

        cont_qs = _continue_learning_courses(request.user)
        continue_data = CourseListSerializer(cont_qs, many=True).data
        my_courses = _my_courses_payload(request, request.user)

        return Response(
            {
                "popular": popular,
                "for_you": for_you,
                "continue": continue_data,
                "my_courses": my_courses,
            }
        )


class PromotionsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        paid_qs = _courses_with_rating_qs(
            Course.objects.filter(is_published=True, price__gt=0)
        ).order_by("-created_at")
        items = []
        meta_names = []
        meta_ends = []
        for c in paid_qs:
            discount = _best_discount_for_course(c)
            if not discount:
                continue
            final_price, _ = _discounted_for_course(c, c.price)
            avg = getattr(c, "rating_avg", None)
            items.append(
                {
                    "id": c.id,
                    "title": c.title,
                    "image": c.image,
                    "base_price": str(c.price),
                    "final_price": str(final_price),
                    "discount_percent": int(discount.percent),
                    "rating_avg": round(float(avg), 2) if avg is not None else None,
                    "rating_count": int(getattr(c, "rating_count", 0) or 0),
                }
            )
            meta_names.append(discount.name)
            meta_ends.append(discount.ends_at)
            if len(items) >= 8:
                break

        if not items:
            return Response(
                {
                    "is_active": False,
                    "name": None,
                    "percent": 0,
                    "ends_at": None,
                    "courses": [],
                }
            )

        uniq_names = set(meta_names)
        banner_name = meta_names[0] if len(uniq_names) == 1 else "Promotions"
        banner_percent = max(int(x["discount_percent"]) for x in items)
        banner_ends = min(meta_ends)

        return Response(
            {
                "is_active": True,
                "name": banner_name,
                "percent": banner_percent,
                "ends_at": banner_ends.isoformat(),
                "courses": PromotionCourseSerializer(items, many=True).data,
            }
        )


# ── Admin CRUD ──

class AdminCategoryViewSet(ModelViewSet):
    queryset = Category.objects.all()
    serializer_class = AdminCategorySerializer
    permission_classes = [IsAdminUser]


class AdminCourseViewSet(ModelViewSet):
    queryset = Course.objects.select_related("category").all()
    serializer_class = AdminCourseSerializer
    permission_classes = [IsAdminUser]


class AdminModuleViewSet(ModelViewSet):
    serializer_class = AdminModuleSerializer
    permission_classes = [IsAdminUser]

    def get_queryset(self):
        qs = Module.objects.all()
        course_id = self.request.query_params.get("course")
        if course_id:
            qs = qs.filter(course_id=course_id)
        return qs


class AdminDiscountViewSet(ModelViewSet):
    queryset = GlobalDiscount.objects.select_related("category").prefetch_related(
        "target_courses"
    ).all()
    serializer_class = GlobalDiscountSerializer
    permission_classes = [IsAdminUser]

    def perform_create(self, serializer):
        discount = serializer.save()
        students = User.objects.filter(is_staff=False, is_active=True)
        for u in students:
            title = "New discount"
            body = (
                f"Promotion «{discount.name}»: -{discount.percent}% "
                f"until {discount.ends_at.astimezone().strftime('%d.%m.%Y %H:%M')}"
            )
            Notification.objects.create(
                user=u,
                title=title,
                body=body,
                target_route="/home",
                type="discount",
            )
            send_push_to_user(u, title=title, body=body)


def _running_discounts_qs():
    now = timezone.now()
    return (
        GlobalDiscount.objects.filter(
            is_active=True, starts_at__lte=now, ends_at__gte=now
        )
        .select_related("category")
        .prefetch_related("target_courses")
        .order_by("-percent", "-created_at")
    )


def _best_discount_for_course(course: Course):
    for d in _running_discounts_qs():
        if d.applies_to_course(course):
            return d
    return None


def _discounted_for_course(course: Course, base_price: Decimal):
    discount = _best_discount_for_course(course)
    if not discount:
        return base_price, None
    factor = (Decimal(100) - Decimal(discount.percent)) / Decimal(100)
    final = (base_price * factor).quantize(Decimal("0.01"))
    return final, discount


def running_discounts_mentor_facts() -> str:
    qs = _running_discounts_qs()
    if not qs.exists():
        return "No active promotions right now."
    lines = []
    for d in qs:
        until = d.ends_at.isoformat()
        if d.scope == GlobalDiscount.Scope.ALL:
            lines.append(
                f"«{d.name}» — {d.percent}% on all paid courses until {until}"
            )
        elif d.scope == GlobalDiscount.Scope.CATEGORY:
            cname = d.category.name if d.category else "?"
            lines.append(
                f"«{d.name}» — {d.percent}% on category «{cname}» until {until}"
            )
        else:
            titles = list(d.target_courses.values_list("title", flat=True)[:10])
            tail = ", ".join(titles) if titles else "(no courses)"
            lines.append(
                f"«{d.name}» — {d.percent}% on selected courses ({tail}) until {until}"
            )
    return "\n".join(lines)


# ── Subscription / Purchase ──

RENEWAL_DAYS = [1, 5, 10]


class SubscriptionStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            course = Course.objects.get(pk=pk)
        except Course.DoesNotExist:
            return Response({"detail": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        final_price, discount = _discounted_for_course(course, course.price)

        if course.is_free:
            return Response({
                "status": "free",
                "is_active": True,
                "price": str(course.price),
                "base_price": str(course.price),
                "final_price": str(course.price),
                "discount_percent": 0,
                "discount_ends_at": None,
            })

        if request.user.is_staff:
            return Response({
                "status": "staff",
                "is_active": True,
                "price": str(course.price),
                "base_price": str(course.price),
                "final_price": str(course.price),
                "discount_percent": 0,
                "discount_ends_at": None,
            })

        sub = (
            Subscription.objects.filter(user=request.user, course=course)
            .order_by("-expires_at")
            .first()
        )

        if sub is None:
            renewal_options = []
            return Response({
                "status": "none",
                "is_active": False,
                "price": str(final_price),
                "base_price": str(course.price),
                "final_price": str(final_price),
                "discount_percent": discount.percent if discount else 0,
                "discount_ends_at": discount.ends_at.isoformat() if discount else None,
                "renewal_options": renewal_options,
            })

        if sub.is_active:
            return Response({
                "status": "active",
                "is_active": True,
                "expires_at": sub.expires_at.isoformat(),
                "price": str(final_price),
                "base_price": str(course.price),
                "final_price": str(final_price),
                "discount_percent": discount.percent if discount else 0,
                "discount_ends_at": discount.ends_at.isoformat() if discount else None,
            })

        renewal_base = (course.price / Decimal(30)).quantize(Decimal("0.01"))
        renewal_final = (final_price / Decimal(30)).quantize(Decimal("0.01"))
        renewal_options = [{"days": d, "price": str((renewal_final * d).quantize(Decimal("0.01")))} for d in RENEWAL_DAYS]
        return Response({
            "status": "expired",
            "is_active": False,
            "expired_at": sub.expires_at.isoformat(),
            "price": str(final_price),
            "base_price": str(course.price),
            "final_price": str(final_price),
            "discount_percent": discount.percent if discount else 0,
            "discount_ends_at": discount.ends_at.isoformat() if discount else None,
            "renewal_options": renewal_options,
        })


class PurchaseCourseView(APIView):
    """First-time purchase: 1 month subscription."""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        if request.user.is_staff:
            return Response(
                {"detail": "Staff do not need to purchase courses."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            course = Course.objects.get(pk=pk)
        except Course.DoesNotExist:
            return Response({"detail": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        if course.is_free:
            return Response({"detail": "Course is free"}, status=status.HTTP_400_BAD_REQUEST)

        existing = Subscription.objects.filter(user=request.user, course=course).exists()
        if existing:
            return Response(
                {"detail": "Already purchased. Use renew endpoint."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        wallet = request.user.wallet
        cost, discount = _discounted_for_course(course, course.price)

        if wallet.balance < cost:
            return Response(
                {
                    "detail": (
                        f"Insufficient wallet balance. Required: {cost} TJS, "
                        f"available: {wallet.balance} TJS. Top up in your profile "
                        f"(an admin can add funds from the panel)."
                    ),
                    "required": str(cost),
                    "balance": str(wallet.balance),
                    "code": "insufficient_balance",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        now = timezone.now()
        wallet.balance -= cost
        wallet.save(update_fields=["balance"])

        Transaction.objects.create(
            wallet=wallet,
            amount=-cost,
            type="purchase",
            description=(
                f"Wallet debit: subscription to «{course.title}» "
                f"for 1 month ({cost} TJS)"
                + (f", discount {discount.percent}%" if discount else "")
            ),
        )
        Notification.objects.create(
            user=request.user,
            title="Course purchase",
            body=f"Your subscription to «{course.title}» is active.",
            target_route=f"/course/{course.id}",
            type="payment",
        )
        send_push_to_user(
            request.user,
            title="Course purchase",
            body=f"Your subscription to «{course.title}» is active.",
        )

        sub = Subscription.objects.create(
            user=request.user,
            course=course,
            starts_at=now,
            expires_at=now + timedelta(days=30),
            is_first=True,
        )

        return Response({
            "detail": "Purchased successfully",
            "expires_at": sub.expires_at.isoformat(),
            "balance": str(wallet.balance),
        })


class RenewCourseView(APIView):
    """Renew subscription for 1, 5, or 10 days."""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        if request.user.is_staff:
            return Response(
                {"detail": "Staff do not need to renew subscriptions."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        days = request.data.get("days")
        if days not in RENEWAL_DAYS:
            return Response(
                {"detail": f"days must be one of {RENEWAL_DAYS}"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            course = Course.objects.get(pk=pk)
        except Course.DoesNotExist:
            return Response({"detail": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        has_first = Subscription.objects.filter(
            user=request.user, course=course, is_first=True
        ).exists()
        if not has_first:
            return Response(
                {"detail": "Must purchase first (1 month) before renewing"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        wallet = request.user.wallet
        final_month, discount = _discounted_for_course(course, course.price)
        cost = ((final_month / Decimal(30)).quantize(Decimal("0.01")) * Decimal(days)).quantize(Decimal("0.01"))

        if wallet.balance < cost:
            return Response(
                {
                    "detail": (
                        f"Insufficient wallet balance. Required: {cost} TJS, "
                        f"available: {wallet.balance} TJS. Top up in your profile."
                    ),
                    "required": str(cost),
                    "balance": str(wallet.balance),
                    "code": "insufficient_balance",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        last_sub = (
            Subscription.objects.filter(user=request.user, course=course)
            .order_by("-expires_at")
            .first()
        )
        start = max(timezone.now(), last_sub.expires_at) if last_sub else timezone.now()

        wallet.balance -= cost
        wallet.save(update_fields=["balance"])

        day_label = "day" if days == 1 else "days"
        Transaction.objects.create(
            wallet=wallet,
            amount=-cost,
            type="renewal",
            description=(
                f"Wallet debit: extended access to «{course.title}» "
                f"by {days} {day_label} ({cost} TJS)"
                + (f", discount {discount.percent}%" if discount else "")
            ),
        )
        ext_body = (
            f"Your access to «{course.title}» was extended by {days} day."
            if days == 1
            else f"Your access to «{course.title}» was extended by {days} days."
        )
        Notification.objects.create(
            user=request.user,
            title="Subscription renewed",
            body=ext_body,
            target_route=f"/course/{course.id}",
            type="payment",
        )
        send_push_to_user(
            request.user,
            title="Subscription renewed",
            body=ext_body,
        )

        sub = Subscription.objects.create(
            user=request.user,
            course=course,
            starts_at=start,
            expires_at=start + timedelta(days=days),
            is_first=False,
        )

        return Response({
            "detail": f"Renewed for {days} days",
            "expires_at": sub.expires_at.isoformat(),
            "balance": str(wallet.balance),
        })

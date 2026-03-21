from datetime import timedelta
from decimal import Decimal

from django.utils import timezone
from rest_framework import status
from rest_framework.generics import ListAPIView, RetrieveAPIView
from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.viewsets import ModelViewSet

from apps.progress.models import LessonProgress
from apps.users.models import Notification, Transaction, User
from apps.users.push import send_push_to_user
from .models import Category, Course, GlobalDiscount, Module, Subscription
from .serializers import (
    AdminCategorySerializer,
    AdminCourseSerializer,
    GlobalDiscountSerializer,
    AdminModuleSerializer,
    CategorySerializer,
    CourseDetailSerializer,
    CourseListSerializer,
)


class CategoryListView(ListAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer


class CourseListView(ListAPIView):
    serializer_class = CourseListSerializer

    def get_queryset(self):
        qs = Course.objects.filter(is_published=True).select_related("category")
        category_id = self.request.query_params.get("category")
        if category_id:
            qs = qs.filter(category_id=category_id)
        return qs


class CourseDetailView(RetrieveAPIView):
    queryset = Course.objects.prefetch_related("modules__lessons").select_related("category")
    serializer_class = CourseDetailSerializer
    permission_classes = [IsAuthenticated]

    def retrieve(self, request, *args, **kwargs):
        course = self.get_object()

        # Админ и бесплатные курсы видят всё.
        if request.user.is_staff or course.is_free:
            return Response(self.get_serializer(course).data)

        has_active = Subscription.objects.filter(
            user=request.user,
            course=course,
            expires_at__gt=timezone.now(),
        ).exists()

        data = self.get_serializer(course).data
        if not has_active:
            # Без оплаты студент видит только описание/превью, но не модули/уроки.
            data["modules"] = []
            data["locked"] = True
            data["locked_reason"] = "subscription_required"
        else:
            data["locked"] = False

        return Response(data)


class ContinueLearningView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        completed_lesson_ids = set(
            LessonProgress.objects.filter(
                user=request.user, is_completed=True
            ).values_list("lesson_id", flat=True)
        )
        if not completed_lesson_ids:
            return Response([])

        course_ids = (
            Course.objects.filter(
                modules__lessons__id__in=completed_lesson_ids
            )
            .distinct()
            .values_list("id", flat=True)
        )

        courses = Course.objects.filter(id__in=course_ids, is_published=True).select_related("category")
        return Response(CourseListSerializer(courses, many=True).data)


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
    queryset = GlobalDiscount.objects.all()
    serializer_class = GlobalDiscountSerializer
    permission_classes = [IsAdminUser]

    def perform_create(self, serializer):
        discount = serializer.save()
        students = User.objects.filter(is_staff=False, is_active=True)
        for u in students:
            title = "Новая скидка"
            body = (
                f"Акция «{discount.name}»: -{discount.percent}% "
                f"до {discount.ends_at.astimezone().strftime('%d.%m.%Y %H:%M')}"
            )
            Notification.objects.create(
                user=u,
                title=title,
                body=body,
                target_route="/home",
                type="discount",
            )
            send_push_to_user(u, title=title, body=body)


def _active_discount():
    now = timezone.now()
    return (
        GlobalDiscount.objects.filter(
            is_active=True, starts_at__lte=now, ends_at__gte=now
        )
        .order_by("-percent", "-created_at")
        .first()
    )


def _discounted(base_price: Decimal):
    discount = _active_discount()
    if not discount:
        return base_price, None
    factor = (Decimal(100) - Decimal(discount.percent)) / Decimal(100)
    final = (base_price * factor).quantize(Decimal("0.01"))
    return final, discount


# ── Subscription / Purchase ──

RENEWAL_DAYS = [1, 5, 10]


class SubscriptionStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            course = Course.objects.get(pk=pk)
        except Course.DoesNotExist:
            return Response({"detail": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        final_price, discount = _discounted(course.price)

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
                {"detail": "Администраторам не нужно оплачивать курсы."},
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
        cost, discount = _discounted(course.price)

        if wallet.balance < cost:
            return Response(
                {
                    "detail": (
                        f"Недостаточно средств на счёте. Нужно: {cost} TJS, "
                        f"на балансе: {wallet.balance} TJS. Пополните баланс в профиле "
                        f"(администратор может пополнить через панель)."
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
                f"Списание со счёта: оплата подписки на курс «{course.title}» "
                f"на 1 месяц ({cost} TJS)"
                + (f", скидка {discount.percent}%" if discount else "")
            ),
        )
        Notification.objects.create(
            user=request.user,
            title="Покупка курса",
            body=f"Вы оформили подписку на курс «{course.title}».",
            target_route=f"/course/{course.id}",
            type="payment",
        )
        send_push_to_user(
            request.user,
            title="Покупка курса",
            body=f"Вы оформили подписку на курс «{course.title}».",
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
                {"detail": "Администраторам не нужно продлевать подписку."},
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
        final_month, discount = _discounted(course.price)
        cost = ((final_month / Decimal(30)).quantize(Decimal("0.01")) * Decimal(days)).quantize(Decimal("0.01"))

        if wallet.balance < cost:
            return Response(
                {
                    "detail": (
                        f"Недостаточно средств на счёте. Нужно: {cost} TJS, "
                        f"на балансе: {wallet.balance} TJS. Пополните баланс в профиле."
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

        day_word = "день" if days == 1 else "дней"
        Transaction.objects.create(
            wallet=wallet,
            amount=-cost,
            type="renewal",
            description=(
                f"Списание со счёта: продление доступа к курсу «{course.title}» "
                f"на {days} {day_word} ({cost} TJS)"
                + (f", скидка {discount.percent}%" if discount else "")
            ),
        )
        Notification.objects.create(
            user=request.user,
            title="Продление подписки",
            body=f"Подписка на курс «{course.title}» продлена на {days} дн.",
            target_route=f"/course/{course.id}",
            type="payment",
        )
        send_push_to_user(
            request.user,
            title="Продление подписки",
            body=f"Подписка на курс «{course.title}» продлена на {days} дн.",
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

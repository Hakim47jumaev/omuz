from django.utils import timezone
from rest_framework import serializers

from apps.lessons.models import Lesson
from .models import Category, Course, CourseReview, GlobalDiscount, Module, Subscription


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ("id", "name", "icon")


class LessonBriefSerializer(serializers.ModelSerializer):
    has_quiz = serializers.SerializerMethodField()

    class Meta:
        model = Lesson
        fields = ("id", "title", "order", "has_quiz")

    def get_has_quiz(self, obj):
        return hasattr(obj, "quiz")


class ModuleSerializer(serializers.ModelSerializer):
    lessons = LessonBriefSerializer(many=True, read_only=True)

    class Meta:
        model = Module
        fields = ("id", "title", "order", "lessons")


class CourseListSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)
    lessons_count = serializers.SerializerMethodField()
    is_free = serializers.BooleanField(read_only=True)
    rating_avg = serializers.SerializerMethodField()
    rating_count = serializers.SerializerMethodField()

    class Meta:
        model = Course
        fields = (
            "id",
            "title",
            "description",
            "image",
            "category",
            "lessons_count",
            "price",
            "is_free",
            "created_at",
            "rating_avg",
            "rating_count",
        )

    def get_lessons_count(self, obj):
        return Lesson.objects.filter(module__course=obj).count()

    def get_rating_avg(self, obj):
        v = getattr(obj, "rating_avg", None)
        if v is None:
            return None
        return round(float(v), 2)

    def get_rating_count(self, obj):
        return int(getattr(obj, "rating_count", 0) or 0)


class CourseDetailSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)
    modules = ModuleSerializer(many=True, read_only=True)
    is_free = serializers.BooleanField(read_only=True)
    rating_avg = serializers.SerializerMethodField()
    rating_count = serializers.SerializerMethodField()
    my_rating = serializers.SerializerMethodField()

    class Meta:
        model = Course
        fields = (
            "id",
            "title",
            "description",
            "preview_video_url",
            "category",
            "modules",
            "price",
            "is_free",
            "created_at",
            "rating_avg",
            "rating_count",
            "my_rating",
        )

    def get_rating_avg(self, obj):
        v = getattr(obj, "rating_avg", None)
        if v is None:
            return None
        return round(float(v), 2)

    def get_rating_count(self, obj):
        return int(getattr(obj, "rating_count", 0) or 0)

    def get_my_rating(self, obj):
        request = self.context.get("request")
        if not request or not request.user.is_authenticated or request.user.is_staff:
            return None
        if not obj.is_free:
            has_access = Subscription.objects.filter(
                user=request.user,
                course=obj,
                expires_at__gt=timezone.now(),
            ).exists()
            if not has_access:
                return None
        rev = CourseReview.objects.filter(user=request.user, course=obj).first()
        return rev.stars if rev else None


class PromotionCourseSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    title = serializers.CharField()
    image = serializers.CharField(allow_blank=True, allow_null=True)
    base_price = serializers.CharField()
    final_price = serializers.CharField()
    discount_percent = serializers.IntegerField()
    rating_avg = serializers.FloatField(allow_null=True, required=False)
    rating_count = serializers.IntegerField(required=False)


# ── Admin write serializers ──

class AdminCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ("id", "name", "icon")


class AdminCourseSerializer(serializers.ModelSerializer):
    class Meta:
        model = Course
        fields = ("id", "title", "description", "image", "preview_video_url", "price", "category", "is_published")


class AdminModuleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Module
        fields = ("id", "course", "title", "order")


class GlobalDiscountSerializer(serializers.ModelSerializer):
    is_running = serializers.BooleanField(read_only=True)
    course_ids = serializers.ListField(
        child=serializers.IntegerField(),
        required=False,
        write_only=True,
    )

    class Meta:
        model = GlobalDiscount
        fields = (
            "id",
            "name",
            "percent",
            "starts_at",
            "ends_at",
            "is_active",
            "is_running",
            "created_at",
            "scope",
            "category",
            "course_ids",
        )
        extra_kwargs = {"category": {"allow_null": True, "required": False}}

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data["course_ids"] = list(instance.target_courses.values_list("id", flat=True))
        return data

    def validate(self, attrs):
        instance = self.instance
        scope = attrs.get("scope", getattr(instance, "scope", GlobalDiscount.Scope.ALL))

        if "category" in attrs:
            category = attrs["category"]
        elif instance:
            category = instance.category
        else:
            category = None

        if "course_ids" in attrs:
            course_ids = attrs["course_ids"]
        elif instance:
            course_ids = list(instance.target_courses.values_list("id", flat=True))
        else:
            course_ids = []

        if scope == GlobalDiscount.Scope.CATEGORY:
            if category is None:
                raise serializers.ValidationError(
                    {"category": "Select a category."},
                )
        if scope == GlobalDiscount.Scope.COURSES:
            if not course_ids:
                raise serializers.ValidationError(
                    {"course_ids": "Select at least one course."},
                )
        return attrs

    def create(self, validated_data):
        course_ids = validated_data.pop("course_ids", [])
        scope = validated_data.get("scope", GlobalDiscount.Scope.ALL)
        if scope == GlobalDiscount.Scope.ALL:
            validated_data["category"] = None
        if scope == GlobalDiscount.Scope.CATEGORY:
            course_ids = []
        if scope == GlobalDiscount.Scope.COURSES:
            validated_data["category"] = None
        obj = GlobalDiscount.objects.create(**validated_data)
        if scope == GlobalDiscount.Scope.COURSES and course_ids:
            obj.target_courses.set(Course.objects.filter(id__in=course_ids))
        return obj

    def update(self, instance, validated_data):
        course_ids = validated_data.pop("course_ids", serializers.empty)
        scope = validated_data.get("scope", instance.scope)
        if scope == GlobalDiscount.Scope.ALL:
            validated_data["category"] = None
        if scope == GlobalDiscount.Scope.CATEGORY and course_ids is not serializers.empty:
            course_ids = []
        if scope == GlobalDiscount.Scope.COURSES:
            validated_data["category"] = None

        instance = super().update(instance, validated_data)
        scope = instance.scope

        if scope == GlobalDiscount.Scope.COURSES:
            if course_ids is not serializers.empty:
                instance.target_courses.set(Course.objects.filter(id__in=course_ids))
        else:
            instance.target_courses.clear()

        return instance

from rest_framework import serializers

from apps.lessons.models import Lesson
from .models import Category, Course, GlobalDiscount, Module


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

    class Meta:
        model = Course
        fields = ("id", "title", "description", "image", "category", "lessons_count", "price", "is_free", "created_at")

    def get_lessons_count(self, obj):
        return Lesson.objects.filter(module__course=obj).count()


class CourseDetailSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)
    modules = ModuleSerializer(many=True, read_only=True)
    is_free = serializers.BooleanField(read_only=True)

    class Meta:
        model = Course
        fields = ("id", "title", "description", "image", "preview_video_url", "category", "modules", "price", "is_free", "created_at")


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
        )

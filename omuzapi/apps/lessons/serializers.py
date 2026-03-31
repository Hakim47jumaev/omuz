from rest_framework import serializers

from .models import Lesson


class LessonDetailSerializer(serializers.ModelSerializer):
    has_quiz = serializers.SerializerMethodField()

    class Meta:
        model = Lesson
        fields = ("id", "title", "description", "video_url", "order", "has_quiz")

    def get_has_quiz(self, obj):
        return hasattr(obj, "quiz")


class AdminLessonSerializer(serializers.ModelSerializer):
    class Meta:
        model = Lesson
        fields = ("id", "module", "title", "description", "video_url", "order")

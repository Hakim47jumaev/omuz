from rest_framework import serializers

from .models import LessonProgress, QuizResult


class LessonProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = LessonProgress
        fields = ("id", "lesson", "video_watched", "quiz_passed", "quiz_score", "is_completed", "completed_at")
        read_only_fields = fields


class QuizResultSerializer(serializers.ModelSerializer):
    class Meta:
        model = QuizResult
        fields = ("id", "quiz", "score", "passed", "completed_at")
        read_only_fields = fields


class ProgressOverviewSerializer(serializers.Serializer):
    completed_lessons = serializers.IntegerField()
    passed_quizzes = serializers.IntegerField()

from rest_framework import serializers

from .models import Answer, Question, Quiz


class AnswerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Answer
        fields = ("id", "text")


class QuestionSerializer(serializers.ModelSerializer):
    answers = AnswerSerializer(many=True, read_only=True)

    class Meta:
        model = Question
        fields = ("id", "text", "order", "answers")


class QuizSerializer(serializers.ModelSerializer):
    questions = QuestionSerializer(many=True, read_only=True)

    class Meta:
        model = Quiz
        fields = ("id", "title", "questions")


class QuizSubmitSerializer(serializers.Serializer):
    """Expected: {answers: {question_id: answer_id, ...}}"""
    answers = serializers.DictField(child=serializers.IntegerField())


# ── Admin serializers ──

class AdminQuizSerializer(serializers.ModelSerializer):
    class Meta:
        model = Quiz
        fields = ("id", "lesson", "title")


class AdminQuestionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Question
        fields = ("id", "quiz", "text", "order")


class AdminAnswerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Answer
        fields = ("id", "question", "text", "is_correct")

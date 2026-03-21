from rest_framework import serializers

from .models import (
    EDUCATION_LEVEL_CHOICES,
    SKILL_CHOICES,
    DeviceToken,
    Notification,
    Resume,
    User,
)


class SendOTPSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)


class VerifyOTPSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)
    otp = serializers.CharField(max_length=6)
    first_name = serializers.CharField(max_length=50, required=False, default="", allow_blank=True)
    last_name = serializers.CharField(max_length=50, required=False, default="", allow_blank=True)


class UserSerializer(serializers.ModelSerializer):
    avatar_url = serializers.SerializerMethodField()

    def get_avatar_url(self, obj):
        if not obj.avatar:
            return None
        req = self.context.get("request")
        if req is not None:
            return req.build_absolute_uri(obj.avatar.url)
        return obj.avatar.url

    class Meta:
        model = User
        fields = ("id", "phone", "first_name", "last_name", "avatar_url", "is_staff", "date_joined")
        read_only_fields = fields


class ResumeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Resume
        fields = (
            "id",
            "current_job",
            "first_name",
            "last_name",
            "patronymic",
            "email",
            "gender",
            "birthday",
            "education_level",
            "skills",
            "education",
            "work_experience",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")


class ResumeListSerializer(serializers.ModelSerializer):
    class Meta:
        model = Resume
        fields = ("id", "first_name", "last_name", "current_job", "updated_at")
        read_only_fields = fields


class SkillChoicesSerializer(serializers.Serializer):
    skills = serializers.ListField(child=serializers.CharField(), read_only=True)
    education_levels = serializers.ListField(read_only=True)


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ("id", "title", "body", "target_route", "type", "is_read", "created_at")
        read_only_fields = fields


class DeviceTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceToken
        fields = ("token", "platform")

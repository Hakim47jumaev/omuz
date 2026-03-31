from datetime import date

from rest_framework import serializers

from rest_framework.fields import empty

from .models import (
    EDUCATION_LEVEL_CHOICES,
    GENDER_CHOICES,
    SKILL_CHOICES,
    DeviceToken,
    Notification,
    Resume,
    User,
)


class _EmptyAsNullDateField(serializers.DateField):
    """Accept '', null, and missing as None (mobile clients often send empty strings)."""

    def to_internal_value(self, data):
        if data is None or data is empty or data == "":
            return None
        return super().to_internal_value(data)


class SendOTPSerializer(serializers.Serializer):
    # E.164: + and up to 15 digits (max ~16 chars); allow margin for formatting.
    phone = serializers.CharField(max_length=20)


class VerifyOTPSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)
    otp = serializers.CharField(max_length=4, min_length=4)
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


class ResumeEducationItemSerializer(serializers.Serializer):
    # Allow blank so parent ResumeSerializer.validate can drop incomplete rows (client bugs / drafts).
    institution = serializers.CharField(max_length=200, required=False, allow_blank=True, default="")
    faculty = serializers.CharField(max_length=200, required=False, allow_blank=True, default="")
    specialization = serializers.CharField(max_length=200, required=False, allow_blank=True, default="")
    graduation_year = serializers.CharField(max_length=10, required=False, allow_blank=True, default="")


class ResumeWorkItemSerializer(serializers.Serializer):
    position = serializers.CharField(max_length=200, required=False, allow_blank=True, default="")
    company = serializers.CharField(max_length=200, required=False, allow_blank=True, default="")
    start_date = serializers.CharField(max_length=50, required=False, allow_blank=True, default="")
    end_date = serializers.CharField(max_length=50, required=False, allow_blank=True, default="")


class ResumeSerializer(serializers.ModelSerializer):
    current_job = serializers.CharField(
        max_length=200, required=False, allow_blank=True, allow_null=True, default=""
    )
    patronymic = serializers.CharField(
        max_length=100, required=False, allow_blank=True, allow_null=True, default=""
    )
    gender = serializers.ChoiceField(
        choices=GENDER_CHOICES, required=False, allow_blank=True, allow_null=True, default=""
    )
    education_level = serializers.ChoiceField(
        choices=EDUCATION_LEVEL_CHOICES, required=False, allow_blank=True, allow_null=True, default=""
    )
    birthday = _EmptyAsNullDateField(required=False, allow_null=True)
    email = serializers.EmailField(required=False, allow_blank=True, allow_null=True)
    skills = serializers.ListField(
        child=serializers.CharField(max_length=80),
        required=False,
        allow_empty=True,
        allow_null=True,
    )
    education = ResumeEducationItemSerializer(many=True, required=False, allow_null=True)
    work_experience = ResumeWorkItemSerializer(many=True, required=False, allow_null=True)

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

    def validate_birthday(self, value):
        if value and value > date.today():
            raise serializers.ValidationError("Birthday cannot be in the future.")
        return value

    def validate_email(self, value):
        if value is None:
            return ""
        s = str(value).strip()
        if not s:
            return ""
        return s.lower()

    def validate_skills(self, value):
        normalized = []
        seen = set()
        for raw in (value if value is not None else []):
            item = (raw or "").strip()
            if not item:
                continue
            key = item.lower()
            if key in seen:
                continue
            seen.add(key)
            normalized.append(item)
        if len(normalized) > 30:
            raise serializers.ValidationError("No more than 30 skills are allowed.")
        return normalized

    def validate(self, attrs):
        if attrs.get("email"):
            attrs["email"] = attrs["email"].strip().lower()

        for field in ("patronymic", "current_job", "gender", "education_level"):
            if attrs.get(field) is None:
                attrs[field] = ""

        for field in ("first_name", "last_name", "patronymic", "current_job"):
            if field in attrs and isinstance(attrs[field], str):
                attrs[field] = attrs[field].strip()

        edu_items = attrs.get("education")
        if edu_items is None:
            attrs["education"] = []
        else:
            attrs["education"] = [
                {
                    "institution": (item.get("institution") or "").strip(),
                    "faculty": (item.get("faculty") or "").strip(),
                    "specialization": (item.get("specialization") or "").strip(),
                    "graduation_year": (item.get("graduation_year") or "").strip(),
                }
                for item in edu_items
                if (item.get("institution") or "").strip()
            ][:15]

        work_items = attrs.get("work_experience")
        if work_items is None:
            attrs["work_experience"] = []
        else:
            attrs["work_experience"] = [
                {
                    "position": (item.get("position") or "").strip(),
                    "company": (item.get("company") or "").strip(),
                    "start_date": (item.get("start_date") or "").strip(),
                    "end_date": (item.get("end_date") or "").strip(),
                }
                for item in work_items
                if (item.get("position") or "").strip() and (item.get("company") or "").strip()
            ][:20]

        return attrs


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

from rest_framework import serializers

from .models import Badge, UserXP, XPTransaction


class UserXPSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserXP
        fields = ("total_xp", "level")


class BadgeSerializer(serializers.ModelSerializer):
    label = serializers.CharField(source="get_badge_type_display")

    class Meta:
        model = Badge
        fields = ("badge_type", "label", "earned_at")


class XPTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = XPTransaction
        fields = ("amount", "reason", "created_at")


class LeaderboardEntrySerializer(serializers.Serializer):
    rank = serializers.IntegerField()
    first_name = serializers.CharField()
    last_name = serializers.CharField()
    total_xp = serializers.IntegerField()
    level = serializers.IntegerField()

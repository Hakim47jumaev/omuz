from django.conf import settings
from django.db import models

BADGE_CHOICES = [
    ("first_lesson", "First Lesson"),
    ("five_lessons", "5 Lessons Completed"),
    ("first_quiz", "First Quiz Passed"),
    ("perfect_score", "Perfect Score"),
    ("first_try_perfect", "Perfect on First Try"),
    ("streak_3", "3 Day Streak"),
]


class UserXP(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="xp"
    )
    total_xp = models.PositiveIntegerField(default=0)
    level = models.PositiveIntegerField(default=1)
    current_streak = models.PositiveIntegerField(default=0)
    best_streak = models.PositiveIntegerField(default=0)
    last_activity_date = models.DateField(blank=True, null=True)

    class Meta:
        verbose_name = "User XP"

    def __str__(self):
        return f"{self.user} — {self.total_xp} XP (Lvl {self.level})"

    def add_xp(self, amount):
        self.total_xp += amount
        self.level = (self.total_xp // 100) + 1
        self.save(update_fields=["total_xp", "level"])


class Badge(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="badges"
    )
    badge_type = models.CharField(max_length=30, choices=BADGE_CHOICES)
    earned_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ["user", "badge_type"]

    def __str__(self):
        return f"{self.user} — {self.get_badge_type_display()}"


class XPTransaction(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="xp_transactions"
    )
    amount = models.IntegerField()
    reason = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user} +{self.amount} ({self.reason})"

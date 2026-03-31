from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.progress.models import LessonProgress, QuizResult
from .models import Badge, XPTransaction
from .xp_utils import apply_daily_streak_bonus, grant_xp

XP_LESSON = 10


def _grant_badge(user, badge_type):
    Badge.objects.get_or_create(user=user, badge_type=badge_type)


@receiver(post_save, sender=LessonProgress)
def on_lesson_complete(sender, instance, **kwargs):
    if not instance.is_completed:
        return

    already_rewarded = XPTransaction.objects.filter(
        user=instance.user, reason=f"Lesson {instance.lesson_id} completed"
    ).exists()
    if already_rewarded:
        return

    grant_xp(instance.user, XP_LESSON, f"Lesson {instance.lesson_id} completed")
    apply_daily_streak_bonus(instance.user)

    completed_count = LessonProgress.objects.filter(
        user=instance.user, is_completed=True
    ).count()

    if completed_count == 1:
        _grant_badge(instance.user, "first_lesson")
    if completed_count >= 5:
        _grant_badge(instance.user, "five_lessons")


@receiver(post_save, sender=QuizResult)
def on_quiz_complete(sender, instance, created, **kwargs):
    # Quiz XP/badges are awarded in quizzes.views based on
    # anti-spam rules (attempt multiplier, cooldown, daily limits).
    return

from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.progress.models import LessonProgress, QuizResult
from .models import Badge, UserXP, XPTransaction

XP_LESSON = 10
XP_QUIZ = 20
XP_PERFECT = 10


def _get_xp(user):
    xp, _ = UserXP.objects.get_or_create(user=user)
    return xp


def _grant_xp(user, amount, reason):
    xp = _get_xp(user)
    xp.add_xp(amount)
    XPTransaction.objects.create(user=user, amount=amount, reason=reason)


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

    _grant_xp(instance.user, XP_LESSON, f"Lesson {instance.lesson_id} completed")

    completed_count = LessonProgress.objects.filter(
        user=instance.user, is_completed=True
    ).count()

    if completed_count == 1:
        _grant_badge(instance.user, "first_lesson")
    if completed_count >= 5:
        _grant_badge(instance.user, "five_lessons")


@receiver(post_save, sender=QuizResult)
def on_quiz_complete(sender, instance, created, **kwargs):
    if not instance.passed:
        return

    already_rewarded = XPTransaction.objects.filter(
        user=instance.user, reason=f"Quiz {instance.quiz_id} passed"
    ).exists()
    if already_rewarded:
        return

    _grant_xp(instance.user, XP_QUIZ, f"Quiz {instance.quiz_id} passed")

    quiz_count = QuizResult.objects.filter(user=instance.user, passed=True).count()
    if quiz_count == 1:
        _grant_badge(instance.user, "first_quiz")

    if instance.score == 100:
        _grant_xp(instance.user, XP_PERFECT, "Perfect score bonus")
        _grant_badge(instance.user, "perfect_score")

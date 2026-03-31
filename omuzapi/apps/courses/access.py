from django.utils import timezone

from .models import Subscription


def user_can_access_lesson(user, lesson) -> bool:
    """Free course, staff, or an active subscription on the course."""
    course = lesson.module.course
    if course.is_free:
        return True
    if user.is_staff:
        return True
    return Subscription.objects.filter(
        user=user, course=course, expires_at__gt=timezone.now()
    ).exists()

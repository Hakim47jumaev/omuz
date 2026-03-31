"""Auto-create a resume draft from profile data (students only)."""

from .models import Resume


def ensure_default_resume(user):
    if user.is_staff:
        return
    if Resume.objects.filter(user=user).exists():
        return
    Resume.objects.create(
        user=user,
        first_name=(user.first_name or "User").strip() or "User",
        last_name=(user.last_name or "").strip(),
        current_job="",
        patronymic="",
        email="",
        gender="",
        education_level="",
        skills=[],
        education=[],
        work_experience=[],
    )

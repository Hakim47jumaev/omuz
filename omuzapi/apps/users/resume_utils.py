"""Авто-создание черновика резюме из данных профиля (только студенты)."""

from .models import Resume


def ensure_default_resume(user):
    if user.is_staff:
        return
    if Resume.objects.filter(user=user).exists():
        return
    Resume.objects.create(
        user=user,
        first_name=(user.first_name or "Пользователь").strip() or "Пользователь",
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

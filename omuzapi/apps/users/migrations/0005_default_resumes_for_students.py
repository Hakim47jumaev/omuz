from django.db import migrations


def create_missing_resumes(apps, schema_editor):
    User = apps.get_model("users", "User")
    Resume = apps.get_model("users", "Resume")
    for u in User.objects.filter(is_staff=False):
        if Resume.objects.filter(user_id=u.pk).exists():
            continue
        Resume.objects.create(
            user_id=u.pk,
            first_name=(u.first_name or "Пользователь").strip() or "Пользователь",
            last_name=(u.last_name or "").strip(),
            current_job="",
            patronymic="",
            email="",
            gender="",
            education_level="",
            skills=[],
            education=[],
            work_experience=[],
        )


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0004_wallet_transaction"),
    ]

    operations = [
        migrations.RunPython(create_missing_resumes, noop),
    ]

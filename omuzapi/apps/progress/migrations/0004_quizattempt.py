from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("quizzes", "0001_initial"),
        ("progress", "0003_lessonprogress_quiz_passed_lessonprogress_quiz_score_and_more"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="QuizAttempt",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("attempt_no", models.PositiveIntegerField(default=1)),
                ("score", models.PositiveIntegerField(default=0, help_text="Percentage 0-100")),
                ("passed", models.BooleanField(default=False)),
                ("xp_awarded", models.IntegerField(default=0)),
                ("submitted_at", models.DateTimeField(auto_now_add=True)),
                ("quiz", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="attempts", to="quizzes.quiz")),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="quiz_attempts", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["-submitted_at"],
            },
        ),
    ]

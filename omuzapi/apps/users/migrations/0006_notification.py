from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0005_default_resumes_for_students"),
    ]

    operations = [
        migrations.CreateModel(
            name="Notification",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("title", models.CharField(max_length=120)),
                ("body", models.TextField()),
                (
                    "type",
                    models.CharField(
                        choices=[
                            ("payment", "Payment"),
                            ("discount", "Discount"),
                            ("course", "Course"),
                            ("system", "System"),
                        ],
                        default="system",
                        max_length=20,
                    ),
                ),
                ("is_read", models.BooleanField(default=False)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=models.deletion.CASCADE,
                        related_name="notifications",
                        to="users.user",
                    ),
                ),
            ],
            options={"ordering": ["-created_at"]},
        ),
    ]

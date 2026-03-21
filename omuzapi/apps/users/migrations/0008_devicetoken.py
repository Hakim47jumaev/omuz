from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0007_notification_target_route"),
    ]

    operations = [
        migrations.CreateModel(
            name="DeviceToken",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("token", models.CharField(max_length=255, unique=True)),
                ("platform", models.CharField(blank=True, default="android", max_length=20)),
                ("is_active", models.BooleanField(default=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=models.deletion.CASCADE,
                        related_name="device_tokens",
                        to="users.user",
                    ),
                ),
            ],
            options={"ordering": ["-updated_at"]},
        ),
    ]

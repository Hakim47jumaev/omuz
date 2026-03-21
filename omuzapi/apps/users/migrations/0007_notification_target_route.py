from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0006_notification"),
    ]

    operations = [
        migrations.AddField(
            model_name="notification",
            name="target_route",
            field=models.CharField(blank=True, max_length=255),
        ),
    ]

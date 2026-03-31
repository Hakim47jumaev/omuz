from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("gamification", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="userxp",
            name="best_streak",
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.AddField(
            model_name="userxp",
            name="current_streak",
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.AddField(
            model_name="userxp",
            name="last_activity_date",
            field=models.DateField(blank=True, null=True),
        ),
    ]

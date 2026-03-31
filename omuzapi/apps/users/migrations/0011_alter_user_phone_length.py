# Generated manually: E.164 with leading + can be up to 16 chars; keep headroom.
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0010_user_email_user_google_sub_alter_user_phone"),
    ]

    operations = [
        migrations.AlterField(
            model_name="user",
            name="phone",
            field=models.CharField(blank=True, max_length=20, null=True, unique=True),
        ),
    ]

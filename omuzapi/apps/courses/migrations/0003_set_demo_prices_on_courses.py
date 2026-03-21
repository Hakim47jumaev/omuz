from decimal import Decimal

from django.db import migrations


def set_prices(apps, schema_editor):
    Course = apps.get_model("courses", "Course")
    # Демо-цена для всех курсов с нулевой ценой (бесплатные → платные для теста)
    Course.objects.filter(price=0).update(price=Decimal("49.99"))


def noop_reverse(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("courses", "0002_course_preview_video_url_course_price_subscription"),
    ]

    operations = [
        migrations.RunPython(set_prices, noop_reverse),
    ]

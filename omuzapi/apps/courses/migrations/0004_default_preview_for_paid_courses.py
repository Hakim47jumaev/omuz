"""Set default YouTube preview for paid courses without preview (demo for all visitors)."""

from django.db import migrations

# Короткое публичное видео — заглушка, в production админ заменит на презентацию курса
DEFAULT_PREVIEW = "https://www.youtube.com/watch?v=jNQXAC9IVRw"


def set_preview(apps, schema_editor):
    Course = apps.get_model("courses", "Course")
    for c in Course.objects.filter(price__gt=0):
        if not (c.preview_video_url or "").strip():
            c.preview_video_url = DEFAULT_PREVIEW
            c.save(update_fields=["preview_video_url"])


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("courses", "0003_set_demo_prices_on_courses"),
    ]

    operations = [
        migrations.RunPython(set_preview, noop),
    ]

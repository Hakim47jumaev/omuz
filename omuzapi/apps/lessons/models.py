from django.db import models


class Lesson(models.Model):
    module = models.ForeignKey(
        "courses.Module", on_delete=models.CASCADE, related_name="lessons"
    )
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    video_url = models.URLField(help_text="YouTube or external video link")
    duration_minutes = models.PositiveSmallIntegerField(
        default=15,
        help_text="Approximate lesson length shown in the app",
    )
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ["order"]

    def __str__(self):
        return self.title

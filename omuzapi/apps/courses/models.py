from django.conf import settings
from django.db import models
from django.utils import timezone
from django.core.validators import MaxValueValidator, MinValueValidator


class Category(models.Model):
    name = models.CharField(max_length=100)
    icon = models.CharField(max_length=50, blank=True)

    class Meta:
        verbose_name_plural = "categories"

    def __str__(self):
        return self.name


class Course(models.Model):
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    category = models.ForeignKey(Category, on_delete=models.CASCADE, related_name="courses")
    image = models.URLField(blank=True)
    preview_video_url = models.URLField(blank=True, help_text="Free preview video for all users")
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0, help_text="Monthly price, 0 = free")
    is_published = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def is_free(self):
        return self.price <= 0

    @property
    def price_per_day(self):
        return (self.price / 30).quantize(self.price.__class__("0.01"))

    def __str__(self):
        return self.title


class CourseReview(models.Model):
    """Course rating 1–5 stars; one review per user (updated on resubmit)."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="course_reviews",
    )
    course = models.ForeignKey(Course, on_delete=models.CASCADE, related_name="reviews")
    stars = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("user", "course")
        ordering = ["-updated_at"]

    def __str__(self):
        return f"{self.user_id} → {self.course_id}: {self.stars}★"


class Module(models.Model):
    course = models.ForeignKey(Course, on_delete=models.CASCADE, related_name="modules")
    title = models.CharField(max_length=200)
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ["order"]

    def __str__(self):
        return f"{self.course.title} → {self.title}"


class Subscription(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="subscriptions"
    )
    course = models.ForeignKey(Course, on_delete=models.CASCADE, related_name="subscriptions")
    starts_at = models.DateTimeField()
    expires_at = models.DateTimeField()
    is_first = models.BooleanField(default=True)

    class Meta:
        ordering = ["-starts_at"]

    @property
    def is_active(self):
        return self.expires_at > timezone.now()

    def __str__(self):
        status = "active" if self.is_active else "expired"
        return f"{self.user} — {self.course.title} ({status})"


class GlobalDiscount(models.Model):
    class Scope(models.TextChoices):
        ALL = "all", "All courses"
        CATEGORY = "category", "One category"
        COURSES = "courses", "Selected courses"

    name = models.CharField(max_length=120)
    percent = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(90)]
    )
    starts_at = models.DateTimeField()
    ends_at = models.DateTimeField()
    is_active = models.BooleanField(default=True)
    scope = models.CharField(
        max_length=20,
        choices=Scope.choices,
        default=Scope.ALL,
    )
    category = models.ForeignKey(
        Category,
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name="global_discounts",
    )
    target_courses = models.ManyToManyField(
        Course,
        blank=True,
        related_name="discount_targets",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    @property
    def is_running(self):
        now = timezone.now()
        return self.is_active and self.starts_at <= now <= self.ends_at

    def applies_to_course(self, course: Course) -> bool:
        if self.scope == self.Scope.ALL:
            return True
        if self.scope == self.Scope.CATEGORY:
            return self.category_id is not None and course.category_id == self.category_id
        if self.scope == self.Scope.COURSES:
            return self.target_courses.filter(pk=course.pk).exists()
        return False

    def __str__(self):
        return f"{self.name} ({self.percent}%)"

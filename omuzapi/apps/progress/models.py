from django.conf import settings
from django.db import models


class LessonProgress(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="lesson_progress"
    )
    lesson = models.ForeignKey("lessons.Lesson", on_delete=models.CASCADE)
    video_watched = models.BooleanField(default=False)
    quiz_passed = models.BooleanField(default=False)
    quiz_score = models.PositiveIntegerField(default=0)
    is_completed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        unique_together = ["user", "lesson"]

    def __str__(self):
        return f"{self.user} — {self.lesson}"

    def check_completion(self):
        """Mark completed when video watched AND (quiz passed OR no quiz exists)."""
        if self.is_completed:
            return False

        if not self.video_watched:
            return False

        has_quiz = hasattr(self.lesson, "quiz")
        if has_quiz and not self.quiz_passed:
            return False

        from django.utils import timezone
        self.is_completed = True
        self.completed_at = timezone.now()
        self.save()
        return True


class QuizResult(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="quiz_results"
    )
    quiz = models.ForeignKey("quizzes.Quiz", on_delete=models.CASCADE)
    score = models.PositiveIntegerField(help_text="Percentage 0-100")
    passed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ["user", "quiz"]

    def __str__(self):
        return f"{self.user} — {self.quiz} ({self.score}%)"


class QuizAttempt(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="quiz_attempts"
    )
    quiz = models.ForeignKey("quizzes.Quiz", on_delete=models.CASCADE, related_name="attempts")
    attempt_no = models.PositiveIntegerField(default=1)
    score = models.PositiveIntegerField(default=0, help_text="Percentage 0-100")
    passed = models.BooleanField(default=False)
    xp_awarded = models.IntegerField(default=0)
    submitted_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-submitted_at"]

    def __str__(self):
        status = "passed" if self.passed else "failed"
        return f"{self.user} — quiz {self.quiz_id} attempt {self.attempt_no} ({status}, {self.score}%)"

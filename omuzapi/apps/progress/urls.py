from django.urls import path

from . import views

app_name = "progress"

urlpatterns = [
    path("mark-video/", views.MarkVideoWatchedView.as_view(), name="mark-video"),
    path("lesson/<int:lesson_id>/", views.LessonStatusView.as_view(), name="lesson-status"),
    path("course/<int:course_id>/", views.CourseProgressView.as_view(), name="course-progress"),
    path("", views.ProgressOverview.as_view(), name="overview"),
]

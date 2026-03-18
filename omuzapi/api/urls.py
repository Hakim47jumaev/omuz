from django.urls import include, path

app_name = "api"

urlpatterns = [
    path("users/", include("apps.users.urls")),
    path("courses/", include("apps.courses.urls")),
    path("lessons/", include("apps.lessons.urls")),
    path("quizzes/", include("apps.quizzes.urls")),
    path("progress/", include("apps.progress.urls")),
]

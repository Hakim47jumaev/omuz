from django.contrib import admin
from django.urls import include, path
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/users/", include("apps.users.urls")),
    path("api/v1/courses/", include("apps.courses.urls")),
    path("api/v1/lessons/", include("apps.lessons.urls")),
    path("api/v1/quizzes/", include("apps.quizzes.urls")),
    path("api/v1/progress/", include("apps.progress.urls")),
    path("api/v1/gamification/", include("apps.gamification.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

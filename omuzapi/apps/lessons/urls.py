from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

app_name = "lessons"

router = DefaultRouter()
router.register("admin/lessons", views.AdminLessonViewSet, basename="admin-lessons")

urlpatterns = [
    path("<int:pk>/", views.LessonDetailView.as_view(), name="detail"),
    path("", include(router.urls)),
]

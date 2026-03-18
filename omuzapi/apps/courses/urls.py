from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

app_name = "courses"

router = DefaultRouter()
router.register("admin/categories", views.AdminCategoryViewSet, basename="admin-categories")
router.register("admin/courses", views.AdminCourseViewSet, basename="admin-courses")
router.register("admin/modules", views.AdminModuleViewSet, basename="admin-modules")

urlpatterns = [
    path("categories/", views.CategoryListView.as_view(), name="categories"),
    path("continue/", views.ContinueLearningView.as_view(), name="continue"),
    path("", views.CourseListView.as_view(), name="list"),
    path("<int:pk>/", views.CourseDetailView.as_view(), name="detail"),
    path("", include(router.urls)),
]

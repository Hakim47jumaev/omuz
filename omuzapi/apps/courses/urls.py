from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

app_name = "courses"

router = DefaultRouter()
router.register("admin/categories", views.AdminCategoryViewSet, basename="admin-categories")
router.register("admin/courses", views.AdminCourseViewSet, basename="admin-courses")
router.register("admin/modules", views.AdminModuleViewSet, basename="admin-modules")
router.register("admin/discounts", views.AdminDiscountViewSet, basename="admin-discounts")

urlpatterns = [
    path("categories/", views.CategoryListView.as_view(), name="categories"),
    path("home-feed/", views.HomeFeedView.as_view(), name="home-feed"),
    path("continue/", views.ContinueLearningView.as_view(), name="continue"),
    path("promotions/", views.PromotionsView.as_view(), name="promotions"),
    path("<int:pk>/subscription/", views.SubscriptionStatusView.as_view(), name="subscription"),
    path("<int:pk>/purchase/", views.PurchaseCourseView.as_view(), name="purchase"),
    path("<int:pk>/renew/", views.RenewCourseView.as_view(), name="renew"),
    path("<int:pk>/review/", views.CourseReviewView.as_view(), name="review"),
    path("", views.CourseListView.as_view(), name="list"),
    path("<int:pk>/", views.CourseDetailView.as_view(), name="detail"),
    path("", include(router.urls)),
]

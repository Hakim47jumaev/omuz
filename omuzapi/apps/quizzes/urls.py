from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

app_name = "quizzes"

router = DefaultRouter()
router.register("admin/quizzes", views.AdminQuizViewSet, basename="admin-quizzes")
router.register("admin/questions", views.AdminQuestionViewSet, basename="admin-questions")
router.register("admin/answers", views.AdminAnswerViewSet, basename="admin-answers")

urlpatterns = [
    path("lesson/<int:lesson_id>/", views.QuizByLessonView.as_view(), name="by-lesson"),
    path("<int:pk>/submit/", views.QuizSubmitView.as_view(), name="submit"),
    path("", include(router.urls)),
]

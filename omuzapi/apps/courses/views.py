from rest_framework.generics import ListAPIView, RetrieveAPIView
from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.viewsets import ModelViewSet

from apps.progress.models import LessonProgress
from .models import Category, Course, Module
from .serializers import (
    AdminCategorySerializer,
    AdminCourseSerializer,
    AdminModuleSerializer,
    CategorySerializer,
    CourseDetailSerializer,
    CourseListSerializer,
)


class CategoryListView(ListAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer


class CourseListView(ListAPIView):
    serializer_class = CourseListSerializer

    def get_queryset(self):
        qs = Course.objects.filter(is_published=True).select_related("category")
        category_id = self.request.query_params.get("category")
        if category_id:
            qs = qs.filter(category_id=category_id)
        return qs


class CourseDetailView(RetrieveAPIView):
    queryset = Course.objects.prefetch_related("modules__lessons").select_related("category")
    serializer_class = CourseDetailSerializer


class ContinueLearningView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        completed_lesson_ids = set(
            LessonProgress.objects.filter(
                user=request.user, is_completed=True
            ).values_list("lesson_id", flat=True)
        )
        if not completed_lesson_ids:
            return Response([])

        course_ids = (
            Course.objects.filter(
                modules__lessons__id__in=completed_lesson_ids
            )
            .distinct()
            .values_list("id", flat=True)
        )

        courses = Course.objects.filter(id__in=course_ids, is_published=True).select_related("category")
        return Response(CourseListSerializer(courses, many=True).data)


# ── Admin CRUD ──

class AdminCategoryViewSet(ModelViewSet):
    queryset = Category.objects.all()
    serializer_class = AdminCategorySerializer
    permission_classes = [IsAdminUser]


class AdminCourseViewSet(ModelViewSet):
    queryset = Course.objects.select_related("category").all()
    serializer_class = AdminCourseSerializer
    permission_classes = [IsAdminUser]


class AdminModuleViewSet(ModelViewSet):
    serializer_class = AdminModuleSerializer
    permission_classes = [IsAdminUser]

    def get_queryset(self):
        qs = Module.objects.all()
        course_id = self.request.query_params.get("course")
        if course_id:
            qs = qs.filter(course_id=course_id)
        return qs

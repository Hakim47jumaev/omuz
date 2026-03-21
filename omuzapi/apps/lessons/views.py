from django.utils import timezone
from rest_framework import status
from rest_framework.generics import RetrieveAPIView
from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.viewsets import ModelViewSet

from apps.courses.models import Subscription
from .models import Lesson
from .serializers import AdminLessonSerializer, LessonDetailSerializer


class LessonDetailView(RetrieveAPIView):
    queryset = Lesson.objects.select_related("module__course").all()
    serializer_class = LessonDetailSerializer
    permission_classes = [IsAuthenticated]

    def retrieve(self, request, *args, **kwargs):
        lesson = self.get_object()
        course = lesson.module.course

        if not course.is_free:
            has_active = Subscription.objects.filter(
                user=request.user, course=course, expires_at__gt=timezone.now()
            ).exists()
            if not has_active and not request.user.is_staff:
                return Response(
                    {"detail": "Subscription required", "course_id": course.id},
                    status=status.HTTP_403_FORBIDDEN,
                )

        serializer = self.get_serializer(lesson)
        return Response(serializer.data)


class AdminLessonViewSet(ModelViewSet):
    serializer_class = AdminLessonSerializer
    permission_classes = [IsAdminUser]

    def get_queryset(self):
        qs = Lesson.objects.all()
        module_id = self.request.query_params.get("module")
        if module_id:
            qs = qs.filter(module_id=module_id)
        return qs

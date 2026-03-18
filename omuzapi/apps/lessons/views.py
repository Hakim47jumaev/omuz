from rest_framework.generics import RetrieveAPIView
from rest_framework.permissions import IsAdminUser
from rest_framework.viewsets import ModelViewSet

from .models import Lesson
from .serializers import AdminLessonSerializer, LessonDetailSerializer


class LessonDetailView(RetrieveAPIView):
    queryset = Lesson.objects.all()
    serializer_class = LessonDetailSerializer


class AdminLessonViewSet(ModelViewSet):
    serializer_class = AdminLessonSerializer
    permission_classes = [IsAdminUser]

    def get_queryset(self):
        qs = Lesson.objects.all()
        module_id = self.request.query_params.get("module")
        if module_id:
            qs = qs.filter(module_id=module_id)
        return qs

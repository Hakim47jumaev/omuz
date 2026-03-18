import io
import logging

from django.http import FileResponse
from django.utils import timezone
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    HRFlowable,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from apps.gamification.models import Badge
from apps.progress.models import LessonProgress

from .models import EDUCATION_LEVEL_CHOICES, SKILL_CHOICES, Resume, User
from .serializers import (
    ResumeListSerializer,
    ResumeSerializer,
    SendOTPSerializer,
    UserSerializer,
    VerifyOTPSerializer,
)

logger = logging.getLogger(__name__)

MOCK_OTP = "1234"


class SendOTPView(APIView):
    def post(self, request):
        ser = SendOTPSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        phone = ser.validated_data["phone"]

        user, created = User.objects.get_or_create(phone=phone)
        is_new = created or not user.first_name
        user.otp_code = MOCK_OTP
        user.otp_created_at = timezone.now()
        user.save(update_fields=["otp_code", "otp_created_at"])

        logger.info("OTP sent to %s | is_new=%s | otp=%s", phone, is_new, MOCK_OTP)
        return Response({"detail": "OTP sent", "otp": MOCK_OTP, "is_new": is_new})


class VerifyOTPView(APIView):
    def post(self, request):
        ser = VerifyOTPSerializer(data=request.data)
        if not ser.is_valid():
            return Response(ser.errors, status=status.HTTP_400_BAD_REQUEST)

        phone = ser.validated_data["phone"]
        otp = ser.validated_data["otp"]

        try:
            user = User.objects.get(phone=phone)
        except User.DoesNotExist:
            return Response({"detail": "User not found"}, status=status.HTTP_404_NOT_FOUND)

        if user.otp_code != otp and otp != MOCK_OTP:
            return Response({"detail": "Invalid OTP"}, status=status.HTTP_400_BAD_REQUEST)

        first_name = ser.validated_data.get("first_name")
        last_name = ser.validated_data.get("last_name")
        if first_name:
            user.first_name = first_name
        if last_name:
            user.last_name = last_name

        user.otp_code = None
        user.otp_created_at = None
        user.save()

        refresh = RefreshToken.for_user(user)
        return Response({
            "access": str(refresh.access_token),
            "refresh": str(refresh),
            "user": UserSerializer(user).data,
        })


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user).data)


# ── Resume CRUD ──────────────────────────────────────────────


class ResumeChoicesView(APIView):
    """Return available skill and education level choices."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response({
            "skills": SKILL_CHOICES,
            "education_levels": [
                {"value": k, "label": v} for k, v in EDUCATION_LEVEL_CHOICES
            ],
        })


class ResumeListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        resumes = Resume.objects.filter(user=request.user)
        return Response(ResumeListSerializer(resumes, many=True).data)

    def post(self, request):
        ser = ResumeSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        ser.save(user=request.user)
        return Response(ser.data, status=status.HTTP_201_CREATED)


class ResumeDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def _get(self, request, pk):
        try:
            return Resume.objects.get(pk=pk, user=request.user)
        except Resume.DoesNotExist:
            return None

    def get(self, request, pk):
        resume = self._get(request, pk)
        if not resume:
            return Response({"detail": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        completed_courses = list(
            LessonProgress.objects.filter(user=request.user, is_completed=True)
            .select_related("lesson__module__course")
            .values_list("lesson__module__course__title", flat=True)
            .distinct()
        )
        badges = Badge.objects.filter(user=request.user).values_list("badge_type", flat=True)
        badge_labels = dict(Badge._meta.get_field("badge_type").choices)

        data = ResumeSerializer(resume).data
        data["completed_courses"] = completed_courses
        data["achievements"] = [badge_labels.get(b, b) for b in badges]
        return Response(data)

    def put(self, request, pk):
        resume = self._get(request, pk)
        if not resume:
            return Response({"detail": "Not found"}, status=status.HTTP_404_NOT_FOUND)
        ser = ResumeSerializer(resume, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        return Response(ser.data)

    def delete(self, request, pk):
        resume = self._get(request, pk)
        if not resume:
            return Response({"detail": "Not found"}, status=status.HTTP_404_NOT_FOUND)
        resume.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ResumeDownloadView(APIView):
    """Generate and return a PDF for a specific resume."""
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            resume = Resume.objects.get(pk=pk, user=request.user)
        except Resume.DoesNotExist:
            return Response({"detail": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        completed_courses = list(
            LessonProgress.objects.filter(user=request.user, is_completed=True)
            .select_related("lesson__module__course")
            .values_list("lesson__module__course__title", flat=True)
            .distinct()
        )
        badges = Badge.objects.filter(user=request.user).values_list("badge_type", flat=True)
        badge_labels = dict(Badge._meta.get_field("badge_type").choices)
        achievements = [badge_labels.get(b, b) for b in badges]

        buf = _build_pdf(resume, completed_courses, achievements)
        filename = f"resume_{resume.first_name}_{resume.last_name}.pdf".replace(" ", "_")
        return FileResponse(buf, as_attachment=True, filename=filename, content_type="application/pdf")


def _build_pdf(resume, completed_courses, achievements):
    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf, pagesize=A4,
        topMargin=20 * mm, bottomMargin=20 * mm,
        leftMargin=20 * mm, rightMargin=20 * mm,
    )

    styles = getSampleStyleSheet()
    accent = colors.HexColor("#3F51B5")

    name_style = ParagraphStyle("Name", parent=styles["Title"], fontSize=22, textColor=accent, spaceAfter=2)
    sub_style = ParagraphStyle("Sub", parent=styles["Normal"], fontSize=11, textColor=colors.grey, spaceAfter=2)
    section_style = ParagraphStyle("Section", parent=styles["Heading2"], fontSize=13, textColor=accent, spaceBefore=14, spaceAfter=6)
    body = ParagraphStyle("Body", parent=styles["Normal"], fontSize=11, leading=16)
    bold_body = ParagraphStyle("BoldBody", parent=body, fontName="Helvetica-Bold")

    story = []
    full_name = f"{resume.first_name} {resume.last_name}".strip()
    if resume.patronymic:
        full_name += f" {resume.patronymic}"
    story.append(Paragraph(full_name or "User", name_style))

    contact_parts = []
    if resume.email:
        contact_parts.append(resume.email)
    contact_parts.append(resume.user.phone)
    if resume.gender:
        contact_parts.append(dict(resume._meta.get_field("gender").choices).get(resume.gender, ""))
    if resume.birthday:
        contact_parts.append(resume.birthday.strftime("%d.%m.%Y"))
    story.append(Paragraph(" | ".join(contact_parts), sub_style))

    if resume.current_job:
        story.append(Paragraph(resume.current_job, ParagraphStyle("Job", parent=body, fontSize=12, spaceBefore=4, spaceAfter=4)))

    story.append(HRFlowable(width="100%", thickness=1, color=accent))
    story.append(Spacer(1, 4 * mm))

    edu_level = dict(EDUCATION_LEVEL_CHOICES).get(resume.education_level, "")
    if edu_level:
        story.append(Paragraph("Education Level", section_style))
        story.append(Paragraph(edu_level, body))

    if resume.education:
        story.append(Paragraph("Education", section_style))
        for edu in resume.education:
            name = edu.get("institution", "")
            faculty = edu.get("faculty", "")
            spec = edu.get("specialization", "")
            year = edu.get("graduation_year", "")
            story.append(Paragraph(f"<b>{name}</b>", bold_body))
            details = []
            if faculty:
                details.append(f"Faculty: {faculty}")
            if spec:
                details.append(f"Specialization: {spec}")
            if year:
                details.append(f"Year: {year}")
            if details:
                story.append(Paragraph(", ".join(details), body))
            story.append(Spacer(1, 2 * mm))

    if resume.skills:
        story.append(Paragraph("Skills", section_style))
        skill_data = []
        row = []
        for skill in resume.skills:
            row.append(Paragraph(f"&#x2022; {skill}", body))
            if len(row) == 3:
                skill_data.append(row)
                row = []
        if row:
            while len(row) < 3:
                row.append("")
            skill_data.append(row)

        col_w = (A4[0] - 40 * mm) / 3
        t = Table(skill_data, colWidths=[col_w] * 3)
        t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP")]))
        story.append(t)

    if resume.work_experience:
        story.append(Paragraph("Work Experience", section_style))
        for job in resume.work_experience:
            pos = job.get("position", "")
            company = job.get("company", "")
            start = job.get("start_date", "")
            end = job.get("end_date", "") or "Present"
            story.append(Paragraph(f"<b>{pos}</b> - {company}", bold_body))
            story.append(Paragraph(f"{start} - {end}", sub_style))
            story.append(Spacer(1, 2 * mm))

    if completed_courses:
        story.append(Paragraph("Completed Courses", section_style))
        for course in completed_courses:
            story.append(Paragraph(f"&#x2022; {course}", body))

    if achievements:
        story.append(Paragraph("Achievements", section_style))
        for ach in achievements:
            story.append(Paragraph(f"&#x2605; {ach}", body))

    doc.build(story)
    buf.seek(0)
    return buf

import io
import logging
import os
import json
import urllib.error
import urllib.request

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
from decimal import Decimal

from rest_framework import status
from rest_framework import serializers
from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from apps.gamification.models import Badge
from apps.progress.models import LessonProgress

from .models import (
    EDUCATION_LEVEL_CHOICES,
    SKILL_CHOICES,
    Notification,
    Resume,
    Transaction,
    User,
    Wallet,
    DeviceToken,
)
from .resume_utils import ensure_default_resume
from .serializers import (
    ResumeListSerializer,
    ResumeSerializer,
    SendOTPSerializer,
    NotificationSerializer,
    DeviceTokenSerializer,
    UserSerializer,
    VerifyOTPSerializer,
)

logger = logging.getLogger(__name__)

MOCK_OTP = "1234"


def _normalize_phone(raw: str) -> str:
    v = (raw or "").strip()
    # Keep only digits and optional leading plus.
    digits = "".join(ch for ch in v if ch.isdigit())
    if not digits:
        return v
    # Canonical format: +<digits>
    return f"+{digits}"


def _phone_candidates(raw: str) -> list[str]:
    n = _normalize_phone(raw)
    if not n:
        return [raw]
    no_plus = n[1:] if n.startswith("+") else n
    return [n, no_plus]


class SendOTPView(APIView):
    def post(self, request):
        ser = SendOTPSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        phone = ser.validated_data["phone"]
        normalized = _normalize_phone(phone)

        user = User.objects.filter(phone__in=_phone_candidates(phone)).first()
        if user:
            created = False
        else:
            user = User.objects.create(phone=normalized)
            created = True
        is_new = created
        user.otp_code = MOCK_OTP
        user.otp_created_at = timezone.now()
        user.save(update_fields=["otp_code", "otp_created_at"])

        logger.info("OTP sent to %s | is_new=%s | otp=%s", normalized, is_new, MOCK_OTP)
        return Response({"detail": "OTP sent", "otp": MOCK_OTP, "is_new": is_new})


class VerifyOTPView(APIView):
    def post(self, request):
        ser = VerifyOTPSerializer(data=request.data)
        if not ser.is_valid():
            return Response(ser.errors, status=status.HTTP_400_BAD_REQUEST)

        phone = ser.validated_data["phone"]
        otp = ser.validated_data["otp"]

        user = User.objects.filter(phone__in=_phone_candidates(phone)).first()
        if not user:
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

        ensure_default_resume(user)

        refresh = RefreshToken.for_user(user)
        return Response({
            "access": str(refresh.access_token),
            "refresh": str(refresh),
            "user": UserSerializer(user).data,
        })


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user, context={"request": request}).data)


class MeAvatarView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        avatar = request.FILES.get("avatar")
        if avatar is None:
            return Response({"detail": "avatar file is required"}, status=status.HTTP_400_BAD_REQUEST)
        request.user.avatar = avatar
        request.user.save(update_fields=["avatar"])
        return Response(UserSerializer(request.user, context={"request": request}).data)


# ── Wallet ───────────────────────────────────────────────────


class WalletView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.is_staff:
            return Response({
                "balance": "0.00",
                "account_number": "",
                "student_wallet": False,
            })
        wallet, _ = Wallet.objects.get_or_create(
            user=request.user,
            defaults={"account_number": _gen_account_number()},
        )
        return Response({
            "balance": str(wallet.balance),
            "account_number": wallet.account_number,
            "student_wallet": True,
        })


class WalletTransactionsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.is_staff:
            return Response([])
        if not hasattr(request.user, "wallet"):
            return Response([])
        wallet = request.user.wallet
        txns = wallet.transactions.all()[:50]
        return Response([
            {
                "id": t.id,
                "amount": str(t.amount),
                "type": t.type,
                "description": t.description,
                "created_at": t.created_at.isoformat(),
            }
            for t in txns
        ])


class AdminTopUpView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        """List students (non-staff) with balance for top-up."""
        users = User.objects.select_related("wallet").filter(is_active=True, is_staff=False)
        result = []
        for u in users:
            wallet = getattr(u, "wallet", None)
            result.append({
                "id": u.id,
                "phone": u.phone,
                "first_name": u.first_name,
                "last_name": u.last_name,
                "balance": str(wallet.balance) if wallet else "0.00",
            })
        return Response(result)

    def post(self, request):
        """Top up a user's wallet."""
        user_id = request.data.get("user_id")
        amount = request.data.get("amount")

        if not user_id or not amount:
            return Response(
                {"detail": "user_id and amount required"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            amount = Decimal(str(amount))
            if amount <= 0:
                raise ValueError()
        except (ValueError, TypeError):
            return Response(
                {"detail": "amount must be a positive number"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            target_user = User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return Response({"detail": "User not found"}, status=status.HTTP_404_NOT_FOUND)

        wallet, _ = Wallet.objects.get_or_create(
            user=target_user,
            defaults={"account_number": _gen_account_number()},
        )
        wallet.balance += amount
        wallet.save(update_fields=["balance"])

        Transaction.objects.create(
            wallet=wallet,
            amount=amount,
            type="topup",
            description=f"Top up by admin ({request.user.first_name})",
        )

        return Response({
            "detail": "Top up successful",
            "balance": str(wallet.balance),
        })


def _gen_account_number():
    import random
    import string
    while True:
        num = "".join(random.choices(string.digits, k=16))
        if not Wallet.objects.filter(account_number=num).exists():
            return num


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
        ensure_default_resume(request.user)
        resumes = Resume.objects.filter(user=request.user)
        return Response(ResumeListSerializer(resumes, many=True).data)

    def post(self, request):
        payload = request.data.copy() if hasattr(request.data, "copy") else dict(request.data)
        target_user = request.user

        if request.user.is_staff:
            user_id = payload.pop("user_id", None)
            if not user_id:
                return Response(
                    {"detail": "user_id is required for admin"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            try:
                target_user = User.objects.get(pk=user_id, is_staff=False)
            except User.DoesNotExist:
                return Response(
                    {"detail": "Target user not found"},
                    status=status.HTTP_404_NOT_FOUND,
                )

        ser = ResumeSerializer(data=payload)
        ser.is_valid(raise_exception=True)
        ser.save(user=target_user)
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


class NotificationListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        items = Notification.objects.filter(user=request.user)[:50]
        unread = Notification.objects.filter(user=request.user, is_read=False).count()
        return Response({
            "unread_count": unread,
            "results": NotificationSerializer(items, many=True).data,
        })


class NotificationReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        updated = Notification.objects.filter(pk=pk, user=request.user).update(is_read=True)
        if not updated:
            return Response({"detail": "Not found"}, status=status.HTTP_404_NOT_FOUND)
        return Response({"detail": "ok"})


class NotificationDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        item = Notification.objects.filter(pk=pk, user=request.user).first()
        if not item:
            return Response({"detail": "Not found"}, status=status.HTTP_404_NOT_FOUND)
        return Response(NotificationSerializer(item).data)


class NotificationReadAllView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
        return Response({"detail": "ok"})


class DeviceTokenView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        ser = DeviceTokenSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        token = ser.validated_data["token"]
        platform = ser.validated_data.get("platform", "android")
        DeviceToken.objects.update_or_create(
            token=token,
            defaults={
                "user": request.user,
                "platform": platform,
                "is_active": True,
            },
        )
        return Response({"detail": "ok"})


class MentorAskSerializer(serializers.Serializer):
    message = serializers.CharField(max_length=8000)
    history = serializers.ListField(required=False, default=list)
    course_title = serializers.CharField(required=False, allow_blank=True, allow_null=True, max_length=200)
    lesson_title = serializers.CharField(required=False, allow_blank=True, allow_null=True, max_length=200)


class MentorAskView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        ser = MentorAskSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        user_message = ser.validated_data["message"].strip()
        history = ser.validated_data.get("history", [])
        course_title = ser.validated_data.get("course_title", "").strip()
        lesson_title = ser.validated_data.get("lesson_title", "").strip()

        context_parts = []
        if course_title:
            context_parts.append(f"Course: {course_title}")
        if lesson_title:
            context_parts.append(f"Lesson: {lesson_title}")
        context_text = "\n".join(context_parts) if context_parts else "No lesson context."

        messages = [
            {
                "role": "system",
                "content": (
                    "You are OMuz AI mentor for students. Be concise, practical, and friendly. "
                    "Explain in simple steps, give short examples, and suggest what to do next. "
                    "If user asks in Russian, answer in Russian. If asks in English, answer in English."
                ),
            },
            {
                "role": "system",
                "content": f"Learning context:\n{context_text}",
            },
        ]

        # Keep only recent turns and only valid role/content pairs.
        for item in history[-8:]:
            if not isinstance(item, dict):
                continue
            role = item.get("role")
            content = (item.get("content") or "").strip()
            if role in {"user", "assistant"} and content:
                messages.append({"role": role, "content": content[:2000]})

        messages.append({"role": "user", "content": user_message})

        gemini_key = os.getenv("GEMINI_API_KEY", "").strip()
        if gemini_key:
            try:
                preferred_model = os.getenv("GEMINI_MODEL", "gemini-2.0-flash").strip() or "gemini-2.0-flash"
                answer, used_model = self._ask_gemini_with_fallback(
                    preferred_model=preferred_model,
                    api_key=gemini_key,
                    messages=messages,
                )
                return Response(
                    {
                        "answer": answer,
                        "provider": "gemini",
                        "model": used_model,
                        "suggested_actions": [
                            "Объясни еще проще",
                            "Дай короткий план практики на 7 дней",
                            "Сделай 3 вопроса для самопроверки",
                        ],
                    }
                )
            except Exception as e:
                logger.exception("Gemini mentor request failed")
                msg = str(e)
                if "429" in msg or "RESOURCE_EXHAUSTED" in msg:
                    return Response(
                        {
                            "detail": (
                                "Превышен лимит Gemini API (free tier). "
                                "Подождите около 1 минуты и попробуйте снова."
                            ),
                            "code": "ai_quota_exceeded",
                        },
                        status=status.HTTP_429_TOO_MANY_REQUESTS,
                    )
                return Response(
                    {"detail": f"Gemini request failed: {e}"},
                    status=status.HTTP_502_BAD_GATEWAY,
                )

        api_key = os.getenv("OPENAI_API_KEY", "").strip()
        if not api_key:
            return Response(
                {"detail": "AI service is not configured. Missing GEMINI_API_KEY / OPENAI_API_KEY."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        model = os.getenv("OPENAI_MODEL", "gpt-4o-mini").strip() or "gpt-4o-mini"
        try:
            from openai import OpenAI
            client = OpenAI(api_key=api_key)
            result = client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=0.4,
                max_tokens=500,
            )
            answer = (result.choices[0].message.content or "").strip()
            if not answer:
                answer = "I could not generate a reply right now. Please try again."
            return Response(
                {
                    "answer": answer,
                    "provider": "openai",
                    "model": model,
                    "suggested_actions": [
                        "Объясни еще проще",
                        "Дай короткий план практики на 7 дней",
                        "Сделай 3 вопроса для самопроверки",
                    ],
                }
            )
        except Exception as e:
            logger.exception("AI mentor request failed")
            return Response(
                {"detail": f"AI request failed: {e}"},
                status=status.HTTP_502_BAD_GATEWAY,
            )

    def _ask_gemini_with_fallback(self, preferred_model: str, api_key: str, messages: list[dict]) -> tuple[str, str]:
        candidates = []
        for m in [
            preferred_model,
            "gemini-2.0-flash",
            "gemini-2.0-flash-lite",
            "gemini-1.5-flash-latest",
            "gemini-1.5-flash-8b-latest",
        ]:
            if m and m not in candidates:
                candidates.append(m)

        last_error = None
        for model in candidates:
            try:
                answer = self._ask_gemini(model=model, api_key=api_key, messages=messages)
                return answer, model
            except RuntimeError as e:
                msg = str(e)
                if "404" in msg or "NOT_FOUND" in msg:
                    last_error = e
                    continue
                raise
        if last_error is not None:
            raise last_error
        raise RuntimeError("No Gemini model candidates available")

    def _ask_gemini(self, model: str, api_key: str, messages: list[dict]) -> str:
        system_chunks = [m["content"] for m in messages if m.get("role") == "system"]
        convo_chunks = [m for m in messages if m.get("role") in {"user", "assistant"}]

        system_text = "\n\n".join(system_chunks).strip()
        contents = []
        for msg in convo_chunks:
            role = "model" if msg["role"] == "assistant" else "user"
            contents.append({"role": role, "parts": [{"text": msg["content"]}]})

        payload = {
            "contents": contents,
            "generationConfig": {
                "temperature": 0.4,
                "maxOutputTokens": 500,
            },
        }
        if system_text:
            payload["system_instruction"] = {"parts": [{"text": system_text}]}

        url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/"
            f"{model}:generateContent?key={api_key}"
        )
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=25) as resp:
                body = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8", errors="ignore")
            raise RuntimeError(f"{e.code}: {raw}") from e

        candidates = body.get("candidates") or []
        if not candidates:
            raise RuntimeError("Empty Gemini response")
        parts = ((candidates[0].get("content") or {}).get("parts") or [])
        text = "\n".join((p.get("text") or "").strip() for p in parts).strip()
        if not text:
            raise RuntimeError("Gemini returned no text")
        return text

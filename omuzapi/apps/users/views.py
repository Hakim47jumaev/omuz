import io
import logging
import os

from django.conf import settings
from django.http import FileResponse
from django.utils import timezone
from reportlab.lib import colors
from reportlab.lib.enums import TA_RIGHT
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

from apps.courses.access import user_can_access_lesson
from apps.courses.models import Course
from apps.courses.views import running_discounts_mentor_facts
from apps.gamification.models import Badge
from apps.gamification.models import UserXP
from apps.lessons.models import Lesson
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


# Temporary: fixed 4-digit OTP until SMS is integrated (replace with random + provider).
def _generate_otp_code() -> str:
    return "1234"


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
        otp_code = _generate_otp_code()
        user.otp_code = otp_code
        user.otp_created_at = timezone.now()
        user.save(update_fields=["otp_code", "otp_created_at"])

        payload = {"detail": "OTP sent", "is_new": is_new}
        if settings.DEBUG:
            payload["otp"] = otp_code
            logger.debug("OTP for %s (fixed dev code): %s", normalized, otp_code)
        else:
            logger.info("OTP sent to %s | is_new=%s", normalized, is_new)
        return Response(payload)


class VerifyOTPView(APIView):
    def post(self, request):
        ser = VerifyOTPSerializer(data=request.data)
        if not ser.is_valid():
            return Response(ser.errors, status=status.HTTP_400_BAD_REQUEST)

        phone = ser.validated_data["phone"]
        otp = str(ser.validated_data["otp"]).strip()

        user = User.objects.filter(phone__in=_phone_candidates(phone)).first()
        if not user:
            return Response({"detail": "User not found"}, status=status.HTTP_404_NOT_FOUND)

        stored = (user.otp_code or "").strip()
        if stored != otp:
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


class AdminTransactionCheckView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request, pk):
        tx = (
            Transaction.objects.select_related("wallet__user")
            .filter(pk=pk, wallet__user__is_staff=False)
            .first()
        )
        if not tx:
            return Response({"detail": "Transaction not found"}, status=status.HTTP_404_NOT_FOUND)

        buf = _build_transaction_check_pdf(tx, request.user)
        filename = f"payment_check_{tx.id}.pdf"
        return FileResponse(
            buf,
            as_attachment=True,
            filename=filename,
            content_type="application/pdf",
        )


def _build_transaction_check_pdf(tx: Transaction, admin_user: User):
    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        topMargin=20 * mm,
        bottomMargin=20 * mm,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
    )
    styles = getSampleStyleSheet()
    accent = colors.HexColor("#0F4C81")

    h1 = ParagraphStyle(
        "CheckTitle",
        parent=styles["Title"],
        fontSize=20,
        textColor=accent,
        spaceAfter=6,
    )
    sub = ParagraphStyle(
        "CheckSub",
        parent=styles["Normal"],
        fontSize=10,
        textColor=colors.grey,
        spaceAfter=4,
    )
    label = ParagraphStyle(
        "CheckLabel",
        parent=styles["Normal"],
        fontSize=10,
        textColor=colors.HexColor("#666666"),
    )
    value = ParagraphStyle(
        "CheckValue",
        parent=styles["Normal"],
        fontSize=11,
        fontName="Helvetica-Bold",
        textColor=colors.HexColor("#1E1E1E"),
    )

    tx_type_labels = dict(Transaction._meta.get_field("type").choices)
    tx_type = tx_type_labels.get(tx.type, tx.type)
    sign = "+" if tx.amount >= 0 else ""
    amount_text = f"{sign}{tx.amount} TJS"
    user_name = f"{tx.wallet.user.first_name} {tx.wallet.user.last_name}".strip() or tx.wallet.user.phone
    created = tx.created_at.astimezone().strftime("%d.%m.%Y %H:%M")
    generated = timezone.now().astimezone().strftime("%d.%m.%Y %H:%M")

    rows = [
        ["Check ID", f"CHK-{tx.id:08d}"],
        ["Transaction ID", str(tx.id)],
        ["Date", created],
        ["User", user_name],
        ["Phone", tx.wallet.user.phone],
        ["Type", tx_type],
        ["Amount", amount_text],
        ["Description", tx.description or "-"],
        ["Generated by", admin_user.phone],
        ["Generated at", generated],
    ]

    story = [
        Paragraph("Omuz Payment Check", h1),
        Paragraph("Official transaction confirmation", sub),
        HRFlowable(width="100%", thickness=1.2, color=accent),
        Spacer(1, 4 * mm),
    ]

    table_data = [
        [Paragraph(f"<b>{k}</b>", label), Paragraph(v, value)]
        for k, v in rows
    ]
    t = Table(table_data, colWidths=[52 * mm, 120 * mm])
    t.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                ("LINEBELOW", (0, 0), (-1, -1), 0.25, colors.HexColor("#DDDDDD")),
            ]
        )
    )
    story.extend([t, Spacer(1, 6 * mm)])
    story.append(
        Paragraph(
            "This check is generated automatically by Omuz admin panel.",
            sub,
        )
    )

    doc.build(story)
    buf.seek(0)
    return buf


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


def _draw_resume_pdf_page(canvas, doc):
    """OMUZ-branded page shell: teal spine + soft header wash (every page)."""
    pw, ph = A4
    accent = colors.HexColor("#1D6376")
    tint = colors.HexColor("#E8F4F7")
    stripe_w = 4 * mm
    band_h = 38 * mm
    canvas.saveState()
    canvas.setFillColor(accent)
    canvas.rect(0, 0, stripe_w, ph, fill=1, stroke=0)
    canvas.setFillColor(tint)
    canvas.rect(stripe_w, ph - band_h, pw - stripe_w, band_h, fill=1, stroke=0)
    canvas.setStrokeColor(accent)
    canvas.setLineWidth(1.25)
    canvas.line(stripe_w, ph - band_h, pw, ph - band_h)
    canvas.restoreState()


def _build_pdf(resume, completed_courses, achievements):
    """Portrait A4 CV with clear OMUZ visual identity (teal accent, structured sections)."""
    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        topMargin=20 * mm,
        bottomMargin=20 * mm,
        leftMargin=20 * mm,
        rightMargin=20 * mm,
    )

    styles = getSampleStyleSheet()
    ink = colors.HexColor("#1A1A1A")
    muted = colors.HexColor("#5C5C5C")
    rule = colors.HexColor("#D4E8ED")
    accent = colors.HexColor("#1D6376")
    panel = colors.HexColor("#F2FAFB")

    meta_right = ParagraphStyle(
        "RMetaR",
        parent=styles["Normal"],
        fontSize=8,
        textColor=accent,
        alignment=TA_RIGHT,
        leading=10,
        fontName="Helvetica-Bold",
    )
    name_style = ParagraphStyle(
        "RName",
        parent=styles["Title"],
        fontSize=27,
        textColor=ink,
        fontName="Helvetica-Bold",
        leading=31,
        spaceAfter=4,
    )
    headline_style = ParagraphStyle(
        "RHeadline",
        parent=styles["Normal"],
        fontSize=11.5,
        textColor=accent,
        leading=14,
        fontName="Helvetica-Bold",
        spaceAfter=8,
    )
    contact_style = ParagraphStyle(
        "RContact",
        parent=styles["Normal"],
        fontSize=9.5,
        textColor=ink,
        leading=14,
    )
    section_style = ParagraphStyle(
        "RSection",
        parent=styles["Normal"],
        fontSize=9,
        textColor=ink,
        fontName="Helvetica-Bold",
        letterSpacing=1,
        spaceAfter=0,
        leading=12,
    )
    body = ParagraphStyle(
        "RBody",
        parent=styles["Normal"],
        fontSize=10,
        textColor=ink,
        leading=14.5,
    )
    bold_body = ParagraphStyle("RBold", parent=body, fontName="Helvetica-Bold")
    sub_style = ParagraphStyle(
        "RSub",
        parent=styles["Normal"],
        fontSize=9.5,
        textColor=muted,
        leading=13,
    )
    right_sub = ParagraphStyle("RSubR", parent=contact_style, alignment=TA_RIGHT)
    foot_style = ParagraphStyle(
        "RFoot",
        parent=styles["Normal"],
        fontSize=8,
        textColor=muted,
        leading=11,
        spaceBefore=16,
    )
    badge_style = ParagraphStyle(
        "RBadge",
        parent=styles["Normal"],
        fontSize=7.5,
        textColor=colors.white,
        fontName="Helvetica-Bold",
        leading=9,
    )

    bar_w = 3.2 * mm

    def section_rule():
        return HRFlowable(
            width="100%",
            thickness=1,
            color=rule,
            spaceBefore=0,
            spaceAfter=9,
        )

    def add_section(story, label):
        row = Table(
            [[Paragraph("", body), Paragraph(label, section_style)]],
            colWidths=[bar_w, doc.width - bar_w],
        )
        row.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (0, 0), accent),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("LEFTPADDING", (0, 0), (-1, -1), 0),
            ("RIGHTPADDING", (1, 0), (1, 0), 8),
            ("TOPPADDING", (0, 0), (-1, -1), 6),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ]))
        story.append(row)
        story.append(section_rule())

    story = []
    yr = timezone.now().year

    brand_left = Paragraph(
        f'<font name="Helvetica-Bold" size="11" color="#1D6376">OMUZ</font>'
        f'<font size="8" color="#5C5C5C"> · online academy</font>',
        ParagraphStyle("RBrand", parent=styles["Normal"], fontSize=10, leading=13),
    )
    badge_w = 36 * mm
    ref_badge = Table(
        [[Paragraph(f"CV · #{yr}-{resume.id}", badge_style)]],
        colWidths=[badge_w],
    )
    ref_badge.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), accent),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ]))
    story.append(
        Table(
            [[brand_left, ref_badge]],
            colWidths=[doc.width - badge_w, badge_w],
        ),
    )
    story.append(Spacer(1, 5 * mm))

    full_name = f"{resume.first_name} {resume.last_name}".strip()
    if resume.patronymic:
        full_name += f" {resume.patronymic}"
    story.append(Paragraph(full_name or "User", name_style))
    if resume.current_job:
        story.append(Paragraph(resume.current_job.strip(), headline_style))
    else:
        story.append(Spacer(1, 1 * mm))

    story.append(
        HRFlowable(width=32 * mm, thickness=3, color=accent, hAlign="LEFT", spaceAfter=10),
    )

    left_bits = []
    if resume.email:
        left_bits.append(resume.email)
    if resume.user.phone:
        left_bits.append(resume.user.phone)
    right_bits = []
    if resume.gender:
        right_bits.append(dict(resume._meta.get_field("gender").choices).get(resume.gender, ""))
    if resume.birthday:
        right_bits.append(resume.birthday.strftime("%d.%m.%Y"))

    inner_contact_w = doc.width - 24
    contact_inner = Table(
        [
            [
                Paragraph(" · ".join(left_bits) if left_bits else "—", contact_style),
                Paragraph(" · ".join(right_bits) if right_bits else "", right_sub),
            ],
        ],
        colWidths=[inner_contact_w * 0.58, inner_contact_w * 0.42],
    )
    contact_inner.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
    ]))
    contact_box = Table([[contact_inner]], colWidths=[doc.width])
    contact_box.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), panel),
        ("BOX", (0, 0), (-1, -1), 0.75, colors.HexColor("#C5DEE5")),
        ("TOPPADDING", (0, 0), (-1, -1), 10),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
        ("LEFTPADDING", (0, 0), (-1, -1), 12),
        ("RIGHTPADDING", (0, 0), (-1, -1), 12),
    ]))
    story.append(contact_box)
    story.append(
        Table(
            [
                [
                    Paragraph("", body),
                    Paragraph(
                        timezone.now().strftime("Updated %d %b %Y"),
                        ParagraphStyle(
                            "RUpd",
                            parent=styles["Normal"],
                            fontSize=8,
                            textColor=muted,
                            alignment=TA_RIGHT,
                        ),
                    ),
                ]
            ],
            colWidths=[doc.width * 0.5, doc.width * 0.5],
        ),
    )

    edu_level = dict(EDUCATION_LEVEL_CHOICES).get(resume.education_level, "")
    if edu_level:
        add_section(story, "EDUCATION LEVEL")
        story.append(Paragraph(edu_level, body))

    if resume.education:
        add_section(story, "EDUCATION")
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
        add_section(story, "SKILLS")
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
        col_w = doc.width / 3
        t = Table(skill_data, colWidths=[col_w] * 3)
        t.setStyle(TableStyle([
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("LEFTPADDING", (0, 0), (-1, -1), 0),
            ("RIGHTPADDING", (0, 0), (-1, -1), 6),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
        ]))
        story.append(t)

    if resume.work_experience:
        add_section(story, "EXPERIENCE")
        for job in resume.work_experience:
            pos = job.get("position", "")
            company = job.get("company", "")
            start = job.get("start_date", "")
            end = job.get("end_date", "") or "Present"
            story.append(Paragraph(f"<b>{pos}</b> — {company}", bold_body))
            story.append(Paragraph(f"{start} — {end}", sub_style))
            story.append(Spacer(1, 2 * mm))

    if completed_courses:
        add_section(story, "COURSES ON OMUZ")
        for course in completed_courses:
            story.append(Paragraph(f"&#x2022; {course}", body))

    if achievements:
        add_section(story, "ACHIEVEMENTS")
        for ach in achievements:
            story.append(Paragraph(f"&#x2022; {ach}", body))

    story.append(HRFlowable(width="100%", thickness=0.5, color=rule, spaceBefore=4, spaceAfter=8))
    story.append(
        Paragraph(
            f'<font color="#1D6376"><b>OMUZ</b></font> · omuz.tj · document ref #{yr}-{resume.id}',
            foot_style,
        ),
    )

    doc.build(story, onFirstPage=_draw_resume_pdf_page, onLaterPages=_draw_resume_pdf_page)
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


def _mentor_course_catalog_block(limit=40):
    qs = (
        Course.objects.filter(is_published=True)
        .select_related("category")
        .order_by("title")[:limit]
    )
    lines = []
    for c in qs:
        cat = (c.category.name or "").strip() if c.category_id else ""
        if cat:
            lines.append(f"- {c.title} — category: {cat}")
        else:
            lines.append(f"- {c.title}")
    return "\n".join(lines) if lines else "- (no published courses)"


def _mentor_student_snapshot(user):
    xp = UserXP.objects.filter(user=user).first()
    completed_lessons = LessonProgress.objects.filter(
        user=user,
        is_completed=True,
    ).count()
    badges_count = Badge.objects.filter(user=user).count()
    full_name = " ".join(
        part for part in [user.first_name, user.last_name] if part
    ).strip()
    return (
        f"Student name: {full_name or 'Unknown'}\n"
        f"Student role: {'admin' if user.is_staff else 'student'}\n"
        f"Completed lessons: {completed_lessons}\n"
        f"Earned badges: {badges_count}\n"
        f"XP: {(xp.total_xp if xp else 0)}\n"
        f"Level: {(xp.level if xp else 1)}\n"
        f"Current streak: {(xp.current_streak if xp else 0)}"
    )


class MentorAskSerializer(serializers.Serializer):
    message = serializers.CharField(max_length=8000)
    history = serializers.ListField(required=False, default=list)
    lesson_id = serializers.IntegerField(required=False, allow_null=True, min_value=1)


class MentorAskView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        ser = MentorAskSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        user_message = ser.validated_data["message"].strip()
        history = ser.validated_data.get("history", [])
        lesson_id = ser.validated_data.get("lesson_id")

        max_tokens = 600
        fmt_hint = (
            "Formatting: use Markdown readable on mobile — short ### headings if useful, "
            "bullet lines starting with '- ', numbered steps '1. ', blank line between sections. "
            "Do not use wide tables."
        )
        suggested_actions = [
            "Which course should I take?",
            "Are there any discounts right now?",
            "How do lessons and quizzes work?",
        ]

        if lesson_id:
            try:
                lesson = Lesson.objects.select_related("module__course").get(pk=lesson_id)
            except Lesson.DoesNotExist:
                return Response(
                    {"detail": "Lesson not found."},
                    status=status.HTTP_404_NOT_FOUND,
                )
            if not user_can_access_lesson(request.user, lesson):
                return Response(
                    {"detail": "Subscription required for this course."},
                    status=status.HTTP_403_FORBIDDEN,
                )
            course = lesson.module.course
            body = (lesson.description or "").strip()
            if len(body) > 6000:
                body = body[:6000] + "\n[…truncated]"
            catalog_block = _mentor_course_catalog_block()
            lesson_block = (
                f"Course: {course.title}\n"
                f"Lesson title: {lesson.title}\n"
                f"Lesson description / material (anchor; expand within the same subject area):\n"
                f"{body or '(no description — infer the topic from course and lesson titles)'}"
            )
            system_main = (
                "You are Omuz AI tutor. The student is viewing a lesson inside a course. "
                "Answer questions about the SUBJECT FIELD and learning path of this course and lesson — "
                "not only the literal lesson text. Use the lesson material below as the main anchor; "
                "you may explain related ideas, prerequisites, examples, and study tips in the same discipline. "
                "If the user describes their interests or asks what to study, recommend suitable courses from the "
                "COURSE CATALOG block only (by title/category); if nothing fits, say so. "
                "Refuse clearly unrelated topics (politics, other apps, random trivia, personal medical/legal advice). "
                "Reply in clear English unless the user writes in another language. " + fmt_hint
            )
            messages = [
                {"role": "system", "content": system_main},
                {"role": "system", "content": lesson_block},
                {
                    "role": "system",
                    "content": "COURSE CATALOG (recommend only these; do not invent courses):\n" + catalog_block,
                },
                {
                    "role": "system",
                    "content": "Student progress snapshot:\n" + _mentor_student_snapshot(request.user),
                },
            ]
            max_tokens = 800
            suggested_actions = [
                "Explain more simply",
                "Which courses fit my goals?",
                "Three quick self-check questions",
            ]
        else:
            discount_line = "Active promotions:\n" + running_discounts_mentor_facts()
            catalog = _mentor_course_catalog_block()
            system_main = (
                "You are Omuz in-app assistant (mobile learning app). Topics: choosing courses from the catalog "
                "(by interest or category), how the app works (lessons, video, quizzes, XP, leaderboard, subscriptions, "
                "wallet in general terms), promotions/discounts, resume and notifications if relevant. "
                "Refuse off-topic questions (unrelated trivia, politics, medical/legal as professional advice, other apps) "
                "with one short line that you only help with Omuz. "
                "Do not invent discounts or courses not listed in Verified facts. "
                "Reply in clear English unless the user writes in another language. " + fmt_hint
            )
            home_facts = f"{discount_line}\n\nPublished courses:\n{catalog}"
            messages = [
                {"role": "system", "content": system_main},
                {"role": "system", "content": f"Verified facts:\n{home_facts}"},
                {
                    "role": "system",
                    "content": "Student snapshot:\n" + _mentor_student_snapshot(request.user),
                },
            ]

        # Keep only recent turns and only valid role/content pairs.
        for item in history[-10:]:
            if not isinstance(item, dict):
                continue
            role = item.get("role")
            content = (item.get("content") or "").strip()
            if role in {"user", "assistant"} and content:
                messages.append({"role": role, "content": content[:2000]})

        messages.append({"role": "user", "content": user_message})

        provider = os.getenv("AI_PROVIDER", "openai").strip().lower() or "openai"
        try:
            if provider == "gemini":
                api_key = os.getenv("GEMINI_API_KEY", "").strip()
                if not api_key:
                    return Response(
                        {"detail": "AI service is not configured. Missing GEMINI_API_KEY."},
                        status=status.HTTP_503_SERVICE_UNAVAILABLE,
                    )

                model = os.getenv("GEMINI_MODEL", "gemini-2.5-flash").strip() or "gemini-2.5-flash"
                import google.generativeai as genai

                genai.configure(api_key=api_key)

                # Gemini SDK in this package accepts a single prompt; flatten chat history.
                prompt_lines = []
                for m in messages:
                    role = m.get("role", "user")
                    content = (m.get("content") or "").strip()
                    if content:
                        prompt_lines.append(f"{role.upper()}: {content}")
                prompt = "\n\n".join(prompt_lines)

                gemini_model = genai.GenerativeModel(model)
                result = gemini_model.generate_content(prompt)
                answer = ((getattr(result, "text", None) or "")).strip()
                provider_name = "gemini"
            else:
                api_key = os.getenv("OPENAI_API_KEY", "").strip()
                if not api_key:
                    return Response(
                        {"detail": "AI service is not configured. Missing OPENAI_API_KEY."},
                        status=status.HTTP_503_SERVICE_UNAVAILABLE,
                    )

                model = os.getenv("OPENAI_MODEL", "gpt-4o-mini").strip() or "gpt-4o-mini"
                from openai import OpenAI

                client = OpenAI(api_key=api_key)
                result = client.chat.completions.create(
                    model=model,
                    messages=messages,
                    temperature=0.35,
                    max_tokens=max_tokens,
                )
                answer = (result.choices[0].message.content or "").strip()
                provider_name = "openai"

            if not answer:
                answer = "I could not generate a reply right now. Please try again."
            return Response(
                {
                    "answer": answer,
                    "provider": provider_name,
                    "model": model,
                    "suggested_actions": suggested_actions,
                }
            )
        except Exception as e:
            logger.exception("AI mentor request failed")
            return Response(
                {"detail": f"AI request failed: {e}"},
                status=status.HTTP_502_BAD_GATEWAY,
            )


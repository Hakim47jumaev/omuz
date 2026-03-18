from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models


class UserManager(BaseUserManager):
    def create_user(self, phone, first_name="", last_name="", **extra):
        if not phone:
            raise ValueError("Phone number is required")
        user = self.model(phone=phone, first_name=first_name, last_name=last_name, **extra)
        user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, phone, first_name="", last_name="", password=None, **extra):
        extra.setdefault("is_staff", True)
        extra.setdefault("is_superuser", True)
        user = self.model(phone=phone, first_name=first_name, last_name=last_name, **extra)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user


class User(AbstractBaseUser, PermissionsMixin):
    phone = models.CharField(max_length=15, unique=True)
    first_name = models.CharField(max_length=50, blank=True)
    last_name = models.CharField(max_length=50, blank=True)

    skills = models.TextField(blank=True, help_text="Comma-separated skills")

    otp_code = models.CharField(max_length=6, blank=True, null=True)
    otp_created_at = models.DateTimeField(blank=True, null=True)

    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(auto_now_add=True)

    objects = UserManager()

    USERNAME_FIELD = "phone"
    REQUIRED_FIELDS = ["first_name", "last_name"]

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.phone})"


GENDER_CHOICES = [("male", "Male"), ("female", "Female")]

EDUCATION_LEVEL_CHOICES = [
    ("higher", "Higher education"),
    ("secondary_special", "Secondary special"),
    ("secondary", "General secondary"),
    ("phd", "PhD"),
    ("doctorate", "Doctorate"),
    ("bachelor", "Bachelor"),
    ("master", "Master"),
]

SKILL_CHOICES = [
    "Programming",
    "Design",
    "Marketing",
    "Project Management",
    "Finance",
    "Analytics",
    "Writing",
    "Languages",
    "Data Science",
    "DevOps",
    "Mobile Development",
    "Web Development",
    "Machine Learning",
    "Databases",
    "Networking",
    "Cybersecurity",
    "Cloud Computing",
    "UI/UX",
    "Testing/QA",
    "Leadership",
]


class Resume(models.Model):
    user = models.ForeignKey("User", on_delete=models.CASCADE, related_name="resumes")
    current_job = models.CharField(max_length=200, blank=True)

    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    patronymic = models.CharField(max_length=100, blank=True)
    email = models.EmailField(blank=True)
    gender = models.CharField(max_length=10, choices=GENDER_CHOICES, blank=True)
    birthday = models.DateField(blank=True, null=True)

    education_level = models.CharField(
        max_length=30, choices=EDUCATION_LEVEL_CHOICES, blank=True
    )

    skills = models.JSONField(default=list, blank=True)
    education = models.JSONField(default=list, blank=True)
    work_experience = models.JSONField(default=list, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]

    def __str__(self):
        return f"Resume: {self.first_name} {self.last_name}"

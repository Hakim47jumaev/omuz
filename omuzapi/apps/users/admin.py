from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from .models import DeviceToken, Notification, User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ("phone", "first_name", "last_name", "is_active", "date_joined")
    search_fields = ("phone", "first_name", "last_name")
    ordering = ("-date_joined",)

    fieldsets = (
        (None, {"fields": ("phone",)}),
        ("Personal", {"fields": ("first_name", "last_name")}),
        ("OTP", {"fields": ("otp_code", "otp_created_at")}),
        ("Permissions", {"fields": ("is_active", "is_staff", "is_superuser")}),
    )
    add_fieldsets = (
        (None, {"classes": ("wide",), "fields": ("phone", "first_name", "last_name")}),
    )


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "title", "type", "is_read", "created_at")
    list_filter = ("type", "is_read")
    search_fields = ("title", "body", "user__phone")
    ordering = ("-created_at",)


@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "platform", "is_active", "updated_at")
    list_filter = ("platform", "is_active")
    search_fields = ("user__phone", "token")
    ordering = ("-updated_at",)

from django.contrib import admin

from .models import Badge, UserXP, XPTransaction


@admin.register(UserXP)
class UserXPAdmin(admin.ModelAdmin):
    list_display = ("user", "total_xp", "level")


@admin.register(Badge)
class BadgeAdmin(admin.ModelAdmin):
    list_display = ("user", "badge_type", "earned_at")


@admin.register(XPTransaction)
class XPTransactionAdmin(admin.ModelAdmin):
    list_display = ("user", "amount", "reason", "created_at")

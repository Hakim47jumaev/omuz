from django.contrib import admin

from .models import Category, Course, CourseReview, Module


class ModuleInline(admin.TabularInline):
    model = Module
    extra = 1


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ("name", "icon")


@admin.register(Course)
class CourseAdmin(admin.ModelAdmin):
    list_display = ("title", "category", "is_published", "created_at")
    list_filter = ("category", "is_published")
    inlines = [ModuleInline]


@admin.register(CourseReview)
class CourseReviewAdmin(admin.ModelAdmin):
    list_display = ("user", "course", "stars", "updated_at")
    list_filter = ("stars",)
    search_fields = ("user__phone", "course__title")

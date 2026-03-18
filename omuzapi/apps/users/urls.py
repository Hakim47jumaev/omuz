from django.urls import path

from . import views

app_name = "users"

urlpatterns = [
    path("send-otp/", views.SendOTPView.as_view(), name="send-otp"),
    path("verify-otp/", views.VerifyOTPView.as_view(), name="verify-otp"),
    path("me/", views.MeView.as_view(), name="me"),
    path("resume/choices/", views.ResumeChoicesView.as_view(), name="resume-choices"),
    path("resume/", views.ResumeListCreateView.as_view(), name="resume-list"),
    path("resume/<int:pk>/", views.ResumeDetailView.as_view(), name="resume-detail"),
    path("resume/<int:pk>/download/", views.ResumeDownloadView.as_view(), name="resume-download"),
]

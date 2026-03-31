from django.urls import path

from . import views

app_name = "users"

urlpatterns = [
    path("send-otp/", views.SendOTPView.as_view(), name="send-otp"),
    path("verify-otp/", views.VerifyOTPView.as_view(), name="verify-otp"),
    path("me/", views.MeView.as_view(), name="me"),
    path("me/avatar/", views.MeAvatarView.as_view(), name="me-avatar"),
    path("wallet/", views.WalletView.as_view(), name="wallet"),
    path("wallet/transactions/", views.WalletTransactionsView.as_view(), name="wallet-transactions"),
    path("admin/topup/", views.AdminTopUpView.as_view(), name="admin-topup"),
    path(
        "admin/transactions/<int:pk>/check/",
        views.AdminTransactionCheckView.as_view(),
        name="admin-transaction-check",
    ),
    path("resume/choices/", views.ResumeChoicesView.as_view(), name="resume-choices"),
    path("resume/", views.ResumeListCreateView.as_view(), name="resume-list"),
    path("resume/<int:pk>/", views.ResumeDetailView.as_view(), name="resume-detail"),
    path("resume/<int:pk>/download/", views.ResumeDownloadView.as_view(), name="resume-download"),
    path("notifications/", views.NotificationListView.as_view(), name="notifications"),
    path("notifications/<int:pk>/", views.NotificationDetailView.as_view(), name="notification-detail"),
    path("notifications/read-all/", views.NotificationReadAllView.as_view(), name="notifications-read-all"),
    path("notifications/<int:pk>/read/", views.NotificationReadView.as_view(), name="notification-read"),
    path("device-token/", views.DeviceTokenView.as_view(), name="device-token"),
    path("ai/mentor/ask/", views.MentorAskView.as_view(), name="ai-mentor-ask"),
]

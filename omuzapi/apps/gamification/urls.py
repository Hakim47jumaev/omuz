from django.urls import path

from . import views

app_name = "gamification"

urlpatterns = [
    path("profile/", views.ProfileView.as_view(), name="profile"),
    path("leaderboard/", views.LeaderboardView.as_view(), name="leaderboard"),
    path("analytics/", views.AnalyticsView.as_view(), name="analytics"),
]

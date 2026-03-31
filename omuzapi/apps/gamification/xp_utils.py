from datetime import timedelta

from django.db.models import Sum
from django.utils import timezone

from .models import UserXP, XPTransaction

DAILY_STREAK_BONUS_XP = 5


def reconcile_user_xp_from_history(user) -> bool:
    """
    Align UserXP.total_xp and level with the sum of XPTransaction rows.
    Streak fields are left unchanged (not represented in transactions).
    Returns True if the row was updated.
    """
    raw = (
        XPTransaction.objects.filter(user=user).aggregate(s=Sum("amount"))["s"]
        or 0
    )
    total = max(0, int(raw))
    xp, _ = UserXP.objects.get_or_create(user=user)
    expected_level = (total // 100) + 1 if total > 0 else 1
    if xp.total_xp != total or xp.level != expected_level:
        xp.total_xp = total
        xp.level = expected_level
        xp.save(update_fields=["total_xp", "level"])
        return True
    return False


def grant_xp(user, amount: int, reason: str) -> int:
    if amount <= 0:
        return 0
    xp, _ = UserXP.objects.get_or_create(user=user)
    xp.add_xp(amount)
    XPTransaction.objects.create(user=user, amount=amount, reason=reason)
    return amount


def apply_daily_streak_bonus(user) -> int:
    """
    Apply streak progression once per local day.
    Returns awarded bonus XP (0 if already counted today).
    """
    xp, _ = UserXP.objects.get_or_create(user=user)
    today = timezone.localdate()
    yesterday = today - timedelta(days=1)

    if xp.last_activity_date == today:
        return 0

    if xp.last_activity_date == yesterday:
        xp.current_streak += 1
    else:
        xp.current_streak = 1

    if xp.current_streak > xp.best_streak:
        xp.best_streak = xp.current_streak

    xp.last_activity_date = today
    xp.save(update_fields=["current_streak", "best_streak", "last_activity_date"])

    return grant_xp(user, DAILY_STREAK_BONUS_XP, f"Daily streak bonus (day {xp.current_streak})")

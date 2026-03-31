"""Cap active subscriptions to at most 30 days ahead; long tails become 1–30 days (deterministic by pk)."""

from datetime import timedelta

from django.db import migrations
from django.utils import timezone


def cap_subscription_expires(apps, schema_editor):
    Subscription = apps.get_model("courses", "Subscription")
    now = timezone.now()
    limit = now + timedelta(days=30)
    qs = Subscription.objects.filter(expires_at__gt=limit)
    for sub in qs.iterator(chunk_size=500):
        # Deterministic 1..30 days from now (no random drift between runs).
        days = (sub.pk % 30) + 1
        sub.expires_at = now + timedelta(days=days)
        sub.save(update_fields=["expires_at"])


def noop_reverse(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("courses", "0007_globaldiscount_scope"),
    ]

    operations = [
        migrations.RunPython(cap_subscription_expires, noop_reverse),
    ]

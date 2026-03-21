import os

from .models import DeviceToken


def _ensure_firebase():
    import firebase_admin
    from firebase_admin import credentials

    if firebase_admin._apps:
        return True
    cred_path = os.getenv("FIREBASE_CREDENTIALS_JSON", "").strip()
    if not cred_path:
        return False
    if not os.path.exists(cred_path):
        return False
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)
    return True


def send_push_to_user(user, title: str, body: str):
    from firebase_admin import messaging

    if not _ensure_firebase():
        return
    tokens = list(
        DeviceToken.objects.filter(user=user, is_active=True).values_list("token", flat=True)
    )
    if not tokens:
        return
    msg = messaging.MulticastMessage(
        tokens=tokens,
        notification=messaging.Notification(title=title, body=body),
    )
    resp = messaging.send_each_for_multicast(msg)
    failed = []
    for idx, r in enumerate(resp.responses):
        if not r.success:
            failed.append(tokens[idx])
    if failed:
        DeviceToken.objects.filter(token__in=failed).update(is_active=False)

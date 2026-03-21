import random
import string

from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import User, Wallet


def _generate_account_number():
    """Generate a unique 16-digit account number."""
    while True:
        num = "".join(random.choices(string.digits, k=16))
        if not Wallet.objects.filter(account_number=num).exists():
            return num


@receiver(post_save, sender=User)
def create_wallet(sender, instance, created, **kwargs):
    # Кошелёк только у студентов; у админов оплаты и баланса нет
    if created and not instance.is_staff:
        Wallet.objects.create(user=instance, account_number=_generate_account_number())

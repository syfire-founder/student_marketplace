from .models import Notification


def create_notification(
    recipient,
    sender,
    notification_type,
    message,
    conversation=None,
):
    if recipient == sender:
        return

    Notification.objects.create(
        recipient=recipient,
        sender=sender,
        conversation=conversation,
        notification_type=notification_type,
        message=message,
    )

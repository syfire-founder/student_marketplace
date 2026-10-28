
import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


def populate_conversation_pairs(apps, schema_editor):
    Conversation = apps.get_model("users", "Conversation")
    ConversationPair = apps.get_model("users", "ConversationPair")
    db_alias = schema_editor.connection.alias

    for conversation in Conversation.objects.using(db_alias).order_by("id"):
        participant_ids = list(
            conversation.participants.using(db_alias)
            .values_list("id", flat=True)
            .order_by("id")
        )

        # This model represents a conversation between exactly two users.
        if len(participant_ids) != 2:
            continue

        user_low_id, user_high_id = participant_ids

        existing_pair = (
            ConversationPair.objects.using(db_alias)
            .filter(
                user_low_id=user_low_id,
                user_high_id=user_high_id,
            )
            .first()
        )

        if existing_pair is None:
            ConversationPair.objects.using(db_alias).create(
                user_low_id=user_low_id,
                user_high_id=user_high_id,
                conversation_id=conversation.id,
            )


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0025_message_product"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="ConversationPair",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "conversation",
                    models.OneToOneField(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="pair_record",
                        to="users.conversation",
                    ),
                ),
                (
                    "user_high",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="conversation_pairs_high",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                (
                    "user_low",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="conversation_pairs_low",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "constraints": [
                    models.UniqueConstraint(
                        fields=("user_low", "user_high"),
                        name="unique_conversation_user_pair",
                    ),
                ],
            },
        ),
        migrations.RunPython(
            populate_conversation_pairs,
            migrations.RunPython.noop,
        ),
    ]

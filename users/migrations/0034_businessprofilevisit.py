import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0033_report_review_status_report_reviewed_at_and_more"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="BusinessProfileVisit",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("viewed_at", models.DateTimeField(db_index=True)),
                ("business", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="profile_visits", to="users.businessprofile")),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="business_profile_visits", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ["-viewed_at"]},
        ),
        migrations.AddConstraint(
            model_name="businessprofilevisit",
            constraint=models.UniqueConstraint(fields=("user", "business"), name="unique_business_profile_visit"),
        ),
    ]

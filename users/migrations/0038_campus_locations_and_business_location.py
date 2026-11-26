from django.db import migrations, models
import django.db.models.deletion


UIB_LOCATIONS = [
    "Zik Hall",
    "Independence Hall",
    "Kuti Hall",
    "Bello Hall",
    "Mellanby Hall",
    "Tedder Hall",
    "Queens Hall",
    "Idia Hall",
    "Awo Hall",
    "CMF Hostel",
    "ITH",
    "Talents Hostel",
    "CBN Hostel",
    "Water Brooks",
    "Others",
]


def seed_university_of_ibadan_locations(apps, schema_editor):
    School = apps.get_model("users", "School")
    CampusLocation = apps.get_model("users", "CampusLocation")
    school = School.objects.filter(name__iexact="University of Ibadan").first()
    if school is None:
        return

    for name in UIB_LOCATIONS:
        CampusLocation.objects.update_or_create(
            school=school,
            name=name,
            defaults={"is_other": name == "Others"},
        )


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0037_pendingregistration_school_optional"),
    ]

    operations = [
        migrations.CreateModel(
            name="CampusLocation",
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
                ("name", models.CharField(max_length=100)),
                ("is_other", models.BooleanField(default=False)),
                (
                    "school",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="campus_locations",
                        to="users.school",
                    ),
                ),
            ],
            options={
                "ordering": ["name"],
                "unique_together": {("school", "name")},
            },
        ),
        migrations.AddField(
            model_name="businessprofile",
            name="campus_location",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name="businesses",
                to="users.campuslocation",
            ),
        ),
        migrations.AddField(
            model_name="businessprofile",
            name="location_details",
            field=models.CharField(blank=True, max_length=255),
        ),
        migrations.RunPython(
            seed_university_of_ibadan_locations,
            migrations.RunPython.noop,
        ),
    ]

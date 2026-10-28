from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0029_businessprofile_logo"),
    ]

    operations = [
        migrations.AddField(
            model_name="businessprofile",
            name="is_suspended",
            field=models.BooleanField(default=False),
        ),
    ]

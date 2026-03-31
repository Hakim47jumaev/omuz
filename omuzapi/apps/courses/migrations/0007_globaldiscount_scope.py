from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("courses", "0006_course_review"),
    ]

    operations = [
        migrations.AddField(
            model_name="globaldiscount",
            name="scope",
            field=models.CharField(
                choices=[
                    ("all", "All courses"),
                    ("category", "One category"),
                    ("courses", "Selected courses"),
                ],
                default="all",
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name="globaldiscount",
            name="category",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="global_discounts",
                to="courses.category",
            ),
        ),
        migrations.AddField(
            model_name="globaldiscount",
            name="target_courses",
            field=models.ManyToManyField(
                blank=True,
                related_name="discount_targets",
                to="courses.course",
            ),
        ),
    ]

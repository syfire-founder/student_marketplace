from django.db import models
from django.contrib.auth.models import User


class Category(models.Model):
    name = models.CharField(max_length=100)

    def __str__(self):
        return self.name


class BusinessProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    business_name = models.CharField(max_length=255)
    category = models.ForeignKey(
        Category,
        on_delete=models.CASCADE,
    )

    def __str__(self):
        return f"{self.user.username}'s Business"


class Product(models.Model):
    is_public = models.BooleanField(default=True)
    business = models.ForeignKey(
        BusinessProfile,
        on_delete=models.CASCADE,
    )
    name = models.CharField(max_length=255)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]  # avoids pagination warning

    def __str__(self):
        return self.name

    
    
# Create your models here.

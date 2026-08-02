from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver


class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)

    def __str__(self):
        return self.name

class School(models.Model):
    name = models.CharField(max_length=255, unique=True)
    def __str__(self):
        return self.name

class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    school = models.ForeignKey(
    School,
    on_delete=models.CASCADE,
    null=True,
    blank=True
)

    def __str__(self):
        return f"{self.user.username} - {self.school.name}"


class BusinessProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    
    category = models.ForeignKey(
        Category,
        on_delete=models.CASCADE
    )
    school = models.ForeignKey(
        School,
        on_delete=models.CASCADE
        )
    
    def __str__(self):
        return self.name





class Product(models.Model):

    PRODUCT = "product"
    SERVICE = "service"

    LISTING_TYPE_CHOICES = [
        (PRODUCT, "Product"),
        (SERVICE, "Service"),
    ]

    listing_type = models.CharField(
        max_length=10,
        choices=LISTING_TYPE_CHOICES,
        default=PRODUCT
    )

    business = models.ForeignKey(
        BusinessProfile,
        on_delete=models.CASCADE,
        related_name="products"
    )

    name = models.CharField(max_length=255)

    description = models.TextField(blank=True)

    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True
    )
    is_available = models.BooleanField(default=True)

    is_private = models.BooleanField(default=False, db_index=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.name



class ListingImage(models.Model):

    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name="images"
    )

    image = models.ImageField(upload_to="listing_images/")

    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"image for {self.product.name}"

class Review(models.Model):
    business = models.ForeignKey(
        BusinessProfile,
        on_delete=models.CASCADE,
        related_name="reviews"
    )

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="reviews"
    )

    rating = models.PositiveSmallIntegerField()

    comment = models.TextField(
        blank=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["business", "user"],
                name="one_review_per_user_per_business"
            )
        ]
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.user.username} - {self.business.name} ({self.rating})"

"""
@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    if created:
        UserProfile.objects.create(user=instance)
"""

@receiver(post_save, sender=User)
def save_user_profile(sender, instance, **kwargs):
    if hasattr(instance, 'userprofile'):
        instance.userprofile.save()

class ProductFavorite(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="favorite_products"
    )

    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name="favorited_by"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "product"],
                name="unique_product_favorite"
            )
        ]

    def __str__(self):
        return f"{self.user.username} ❤️ {self.product.name}"


class BusinessFollow(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="followed_businesses"
    )

    business = models.ForeignKey(
        BusinessProfile,
        on_delete=models.CASCADE,
        related_name="followers"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "business"],
                name="unique_business_follow"
            )
        ]

    def __str__(self):
        return f"{self.user.username} follows {self.business.name}"






"""
class Product(models.Model):
    is_private = models.BooleanField(default=False, db_index=True)

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

"""

    
    
# Create your models here.

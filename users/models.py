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
    logo = models.ImageField(upload_to="business_logos/", blank=True, null=True)
    description = models.TextField(blank=True)
    is_suspended = models.BooleanField(default=False)
    
    category = models.ForeignKey(
        Category,
        on_delete=models.PROTECT
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

    category = models.ForeignKey(
        Category,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
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

    is_private = models.BooleanField(
        default=False,
        db_index=True
    )

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


class CommunityMembership(models.Model):
    """A user who joined a business community while following that business."""

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="community_memberships",
    )
    business = models.ForeignKey(
        BusinessProfile,
        on_delete=models.CASCADE,
        related_name="community_memberships",
    )
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "business"],
                name="unique_community_membership",
            )
        ]


class CommunityPost(models.Model):
    IMAGE = "image"
    VIDEO = "video"
    MEDIA_TYPES = [(IMAGE, "Image"), (VIDEO, "Video")]

    business = models.ForeignKey(
        BusinessProfile,
        on_delete=models.CASCADE,
        related_name="community_posts",
    )
    author = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="community_posts",
    )
    message = models.TextField(blank=True)
    media = models.FileField(upload_to="community_posts/", blank=True, null=True)
    media_type = models.CharField(max_length=10, choices=MEDIA_TYPES, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.business.name} community update ({self.pk})"


class ProductView(models.Model):
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name="views"
    )

    user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="product_views"
    )

    viewed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-viewed_at"]

    def __str__(self):
        username = self.user.username if self.user else "Anonymous"
        return f"{username} viewed {self.product.name}"


class BusinessProfileVisit(models.Model):
    """The most recent time a signed-in user opened a business profile."""

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="business_profile_visits",
    )
    business = models.ForeignKey(
        BusinessProfile,
        on_delete=models.CASCADE,
        related_name="profile_visits",
    )
    viewed_at = models.DateTimeField(db_index=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "business"],
                name="unique_business_profile_visit",
            )
        ]
        ordering = ["-viewed_at"]


class AppVisit(models.Model):
    """A signed-in user's visit to the app home screen."""

    user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="app_visits",
    )
    visited_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["-visited_at"]

    def __str__(self):
        username = self.user.username if self.user else "Deleted user"
        return f"{username} visited the app at {self.visited_at}"


class PendingRegistration(models.Model):
    username = models.CharField(max_length=150, unique=True)
    email = models.EmailField(unique=True)
    password_hash = models.CharField(max_length=128)
    school = models.ForeignKey(School, on_delete=models.CASCADE)
    code_hash = models.CharField(max_length=128)
    expires_at = models.DateTimeField(db_index=True)
    last_sent_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)


class AccountRecoveryCode(models.Model):
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="account_recovery_code",
    )
    code_hash = models.CharField(max_length=128)
    expires_at = models.DateTimeField(db_index=True)
    last_sent_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)

class Conversation(models.Model):
    participants = models.ManyToManyField(
        User,
        related_name="conversations"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def has_participant(self, user):
        return self.participants.filter(id=user.id).exists()

    def __str__(self):
        return f"Conversation {self.pk}"


class Message(models.Model):
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name="messages"
    )

    reply_to = models.ForeignKey(
        "self",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="replies",
    )

    product = models.ForeignKey(
        Product,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="messages"
    )

    sender = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="sent_messages"
    )

    text = models.TextField(blank=True)

    attachment = models.FileField(
        upload_to="message_attachments/",
        blank=True,
        null=True,
    )

    attachment_type = models.CharField(
        max_length=10,
        choices=[("photo", "Photo"), ("video", "Video")],
        blank=True,
    )

    is_read = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)

        self.conversation.save(update_fields=["updated_at"])

    def __str__(self):
        return f"{self.sender.username}: {self.text[:30]}"

class ConversationPair(models.Model):
    user_low = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="conversation_pairs_low"
    )

    user_high = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="conversation_pairs_high"
    )

    conversation = models.OneToOneField(
        Conversation,
        on_delete=models.CASCADE,
        related_name="pair_record"
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user_low", "user_high"],
                name="unique_conversation_user_pair"
            )
        ]

    def __str__(self):
        return f"{self.user_low_id} - {self.user_high_id}"

class Notification(models.Model):
    
    FAVORITE = "favorite"
    FOLLOW = "follow"
    REVIEW = "review"
    MESSAGE = "message"

    NOTIFICATION_TYPES = [
        (FAVORITE, "Favorite"),
        (FOLLOW, "Follow"),
        (REVIEW, "Review"),
        (MESSAGE, "Message"),
    ]

    recipient = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="notifications"
    )

    sender = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="sent_notifications"
    )

    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="notifications"
    )

    notification_type = models.CharField(
        max_length=20,
        choices=NOTIFICATION_TYPES
    )

    message = models.CharField(max_length=255)

    is_read = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.sender} -> {self.recipient}"

class Report(models.Model):
    PRODUCT = "product"
    BUSINESS = "business"

    PENDING = "pending"
    ACTION_TAKEN = "action_taken"
    REVIEWED = "reviewed"
    DISMISSED = "dismissed"

    REVIEW_STATUSES = [
        (PENDING, "Pending review"),
        (ACTION_TAKEN, "Action taken"),
        (REVIEWED, "Reviewed"),
        (DISMISSED, "Dismissed"),
    ]

    REPORT_TYPES = [
        (PRODUCT, "Product"),
        (BUSINESS, "Business"),
    ]

    reporter = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="reports"
    )

    report_type = models.CharField(
        max_length=20,
        choices=REPORT_TYPES
    )

    product = models.ForeignKey(
        Product,
        null=True,
        blank=True,
        on_delete=models.CASCADE
    )

    business = models.ForeignKey(
        BusinessProfile,
        null=True,
        blank=True,
        on_delete=models.CASCADE
    )

    reason = models.TextField()

    review_status = models.CharField(
        max_length=20,
        choices=REVIEW_STATUSES,
        default=PENDING,
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    reviewed_by = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="reviewed_reports",
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    def __str__(self):
        return f"{self.reporter.username} reported {self.report_type}"


    
    
# Create your models here.

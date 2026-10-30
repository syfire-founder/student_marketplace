from rest_framework import serializers
from .models import BusinessProfile, Product
from .models import ListingImage
from .models import Category
from django.contrib.auth.models import User
from .models import UserProfile, School
from .models import (
    ProductFavorite,
    BusinessFollow,
)
from .models import (
    Review,
    Notification,
    CommunityMembership,
    CommunityPost,
)
from django.db.models import Avg
from django.urls import reverse
from .models import Conversation, Message, ProductView, Report

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = '__all__'

    def validate_name(self, value):
        value = value.strip().title()

        if Category.objects.filter(name__iexact=value).exists():
            raise serializers.ValidationError(
                "A category with this name already exists."
                )

        return value
    
class BusinessProfileSerializer(serializers.ModelSerializer):
    products = serializers.SerializerMethodField()
    is_owner = serializers.SerializerMethodField()
    category_name = serializers.CharField(
        source="category.name",
        read_only=True
    )

    school = serializers.PrimaryKeyRelatedField(
        read_only=True
    )

    school_name = serializers.CharField(
        source="school.name",
        read_only=True
    )

    class Meta:
        model = BusinessProfile
        fields = [
            "id",
            "name",
            "logo",
            "description",
            "category",
            "category_name",
            "school",
            "school_name",
            "products",
            "is_owner",
        ]

        read_only_fields = [
            "id",
            "school",
            "school_name",
            "category_name",
            "is_owner",
        ]

    def get_is_owner(self, obj):
        request = self.context.get("request")
        return bool(
            request
            and request.user.is_authenticated
            and obj.user_id == request.user.id
        )

    def get_products(self, obj):
        request = self.context.get("request")
        owned_by_request_user = bool(
            request
            and request.user.is_authenticated
            and obj.user_id == request.user.id
        )
        products = obj.products.all()
        if not owned_by_request_user:
            products = products.filter(
                is_available=True,
                is_private=False,
            )
        products = products.select_related(
            "business",
            "category",
        ).prefetch_related("images").order_by("-created_at")
        return ProductSerializer(
            products,
            many=True,
            context=self.context,
        ).data
    
    


class UserRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    email = serializers.EmailField(required=True, allow_blank=False)

    # User chooses their school during registration
    school = serializers.PrimaryKeyRelatedField(
        queryset=School.objects.all(),
        write_only=True
    )

    class Meta:
        model = User
        fields = (
            "username",
            "email",
            "password",
            "school",
        )

    def validate_email(self, value):
        value = value.strip().lower()
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("An account already uses this email.")
        return value

    def create(self, validated_data):
        school = validated_data.pop("school")

        user = User.objects.create_user(
            username=validated_data["username"],
            email=validated_data.get("email"),
            password=validated_data["password"],
        )

        UserProfile.objects.create(
            user=user,
            school=school
        )

        return user

class ListingImageSerializer(serializers.ModelSerializer):

    class Meta:
        model = ListingImage
        fields = [
            "id",
            "product",
            "image",
            "uploaded_at",
        ]

        read_only_fields = [
            "id",
            "product",
            "uploaded_at",
        ]

    def validate_image(self, value):
        if value.size > 2 * 1024 * 1024:
            raise serializers.ValidationError(
                "Image too large. Maximum size is 2MB."
            )

        return value
    


class ProductSerializer(serializers.ModelSerializer):
    images = ListingImageSerializer(many=True, read_only=True)

    seller_id = serializers.IntegerField(
        source="business.user.id",
        read_only=True
    )

    business_name = serializers.CharField(
        source="business.name",
        read_only=True
    )

    category = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.all(),
        required=True,
        allow_null=False,
    )

    description = serializers.CharField(
        allow_blank=False,
        trim_whitespace=True,
    )

    category_name = serializers.CharField(
        source="category.name",
        read_only=True
    )

    school = serializers.IntegerField(
        source="business.school.id",
        read_only=True
    )

    school_name = serializers.CharField(
        source="business.school.name",
        read_only=True
    )

    class Meta:
        model = Product
        fields = [
            "id",
            "listing_type",
            "name",
            "description",
            "price",
            "is_available",
            "is_private",
            "created_at",

            "business",
            "business_name",
            "seller_id",

            "category",
            "category_name",

            "school",
            "school_name",

            "images",
        ]

        read_only_fields = [
            "id",
            "business",
            "business_name",
            "seller_id",
            "category_name",
            "school",
            "school_name",
            "created_at",
        ]
            
        

class SchoolSerializer(serializers.ModelSerializer):
    class Meta:
        model = School
        fields = '__all__'







class ProductFavoriteSerializer(serializers.ModelSerializer):
    product = ProductSerializer(read_only=True)

    class Meta:
        model = ProductFavorite
        fields = ["id", "product", "created_at"]
        read_only_fields = ["id", "product", "created_at"]


class BusinessFollowSerializer(serializers.ModelSerializer):
    class Meta:
        model = BusinessFollow
        fields = [
            "id",
            "business",
            "created_at",
        ]
        read_only_fields = [
            "id",
            "created_at",
        ]

class UserProfileSerializer(serializers.ModelSerializer):
    user_id = serializers.IntegerField(
        source="user.id",
        read_only=True
    )

    username = serializers.CharField(
        source="user.username",
        read_only=True
    )

    school_name = serializers.CharField(
        source="school.name",
        read_only=True
    )

    class Meta:
        model = UserProfile
        fields = [
            "id",
            "user_id",
            "username",
            "school",
            "school_name",
        ]
        read_only_fields = [
            "id",
            "user_id",
            "username",
            "school_name",
        ]





class ReviewSerializer(serializers.ModelSerializer):
    user = serializers.StringRelatedField(read_only=True)
    is_owner = serializers.SerializerMethodField()

    class Meta:
        model = Review
        fields = [
            "id",
            "business",
            "user",
            "is_owner",
            "rating",
            "comment",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "user",
            "is_owner",
            "created_at",
            "updated_at",
        ]

    def get_is_owner(self, obj):
        request = self.context.get("request")
        return bool(
            request
            and request.user.is_authenticated
            and obj.user_id == request.user.id
        )

    def validate_rating(self, value):
        if value < 1 or value > 5:
            raise serializers.ValidationError(
                "Rating must be between 1 and 5."
            )
        return value

    def validate(self, attrs):
        request = self.context["request"]

    # On create, business comes from the request.
    # On update, use the existing business.
        business = attrs.get(
            "business",
            self.instance.business if self.instance else None
        )

        if business.is_suspended:
            raise serializers.ValidationError(
                "You cannot review a suspended business profile."
            )

    # Users cannot review their own business.
        if business.user == request.user:
            raise serializers.ValidationError(
                "You cannot review your own business."
            )

    # One review per user per business.
        if (
            self.instance is None and
            Review.objects.filter(
                business=business,
                user=request.user
            ).exists()
        ):
           raise serializers.ValidationError(
            "You have already reviewed this business."
           )

        return attrs



class BusinessDashboardSerializer(serializers.Serializer):
    business = serializers.CharField()
    followers = serializers.IntegerField()
    products = serializers.IntegerField()
    reviews = serializers.IntegerField()
    average_rating = serializers.FloatField()
    favorites = serializers.IntegerField()
    total_views = serializers.IntegerField()
    top_products = serializers.ListField()
    trending_products = serializers.ListField(read_only=True)
    recent_reviews = serializers.ListField()


class ConversationSerializer(serializers.ModelSerializer):
    participants = serializers.PrimaryKeyRelatedField(
        many=True,
        queryset=User.objects.all()
    )
    other_participant = serializers.SerializerMethodField()
    latest_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    def get_other_participant(self, obj):
        request = self.context.get("request")
        other_user = obj.participants.exclude(id=request.user.id).first()
        if other_user is None:
            return None
        return {
            "id": other_user.id,
            "username": other_user.username,
        }

    def get_latest_message(self, obj):
        message = obj.messages.select_related("sender").order_by("-created_at").first()
        if message is None:
            return None
        preview = message.text.strip()
        if not preview and message.attachment_type:
            preview = "Photo" if message.attachment_type == "photo" else "Video"
        return {
            "text": preview,
            "sender": message.sender.username,
            "is_mine": message.sender_id == self.context["request"].user.id,
            "created_at": message.created_at,
        }

    def get_unread_count(self, obj):
        user = self.context["request"].user
        return obj.messages.exclude(sender=user).filter(is_read=False).count()

    class Meta:
        model = Conversation
        fields = [
            "id",
            "participants",
            "other_participant",
            "latest_message",
            "unread_count",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "created_at",
            "updated_at",
        ]



class MessageSerializer(serializers.ModelSerializer):
    sender = serializers.StringRelatedField(read_only=True)
    is_mine = serializers.SerializerMethodField()
    text = serializers.CharField(required=False, allow_blank=True)
    attachment = serializers.SerializerMethodField()
    attachment_upload = serializers.FileField(
        source="attachment",
        write_only=True,
        required=False,
        allow_null=True,
    )
    product_image = serializers.SerializerMethodField()
    reply_to_text = serializers.SerializerMethodField()
    reply_to_sender = serializers.SerializerMethodField()
    product_name = serializers.CharField(
        source="product.name",
        read_only=True,
        allow_null=True,
    )

    def get_attachment(self, obj):
        if not obj.attachment:
            return None
        request = self.context.get("request")
        path = reverse("message-attachment", kwargs={"pk": obj.pk})
        return request.build_absolute_uri(path) if request else path

    def get_product_image(self, obj):
        if not obj.product_id:
            return None

        listing_image = next(iter(obj.product.images.all()), None)
        if listing_image is None or not listing_image.image:
            return None

        image_url = listing_image.image.url
        request = self.context.get("request")
        if request is not None:
            return request.build_absolute_uri(image_url)
        return image_url

    def get_reply_to_text(self, obj):
        if not obj.reply_to_id:
            return None
        text = obj.reply_to.text.strip()
        if text:
            return text
        if obj.reply_to.attachment_type:
            return "Photo" if obj.reply_to.attachment_type == "photo" else "Video"
        return None

    def get_reply_to_sender(self, obj):
        return obj.reply_to.sender.username if obj.reply_to_id else None

    def get_is_mine(self, obj):
        request = self.context.get("request")
        return bool(request and request.user == obj.sender)

    def validate(self, attrs):
        text = attrs.get("text", getattr(self.instance, "text", ""))
        attachment = attrs.get("attachment", getattr(self.instance, "attachment", None))
        attachment_type = attrs.get(
            "attachment_type",
            getattr(self.instance, "attachment_type", ""),
        )
        if not text.strip() and not attachment:
            raise serializers.ValidationError("Write a message or attach a photo or video.")
        if attachment:
            if attachment.size > 50 * 1024 * 1024:
                raise serializers.ValidationError({"attachment": "Attachments must be 50 MB or smaller."})
            extension = attachment.name.rsplit(".", 1)[-1].lower() if "." in attachment.name else ""
            photo_extensions = {"jpg", "jpeg", "png", "gif", "webp"}
            video_extensions = {"mp4", "mov", "webm", "m4v"}
            expected_type = (
                "photo" if extension in photo_extensions
                else "video" if extension in video_extensions
                else None
            )
            if expected_type is None:
                raise serializers.ValidationError({"attachment": "Choose a supported photo or video file."})
            if attachment_type and attachment_type != expected_type:
                raise serializers.ValidationError({"attachment_type": "The attachment type does not match the file."})
            attrs["attachment_type"] = expected_type
        else:
            attrs["attachment_type"] = ""
        return attrs

    class Meta:
        model = Message
        fields = [
            "id",
            "conversation",
            "product",
            "product_name",
            "product_image",
            "attachment",
            "attachment_upload",
            "attachment_type",
            "reply_to",
            "reply_to_text",
            "reply_to_sender",
            "sender",
            "is_mine",
            "text",
            "is_read",
            "created_at",
        ]
        read_only_fields = [
            "id",
            "sender",
            "is_read",
            "created_at",
            "product_name",
            "product_image",
            "attachment",
            "reply_to_text",
            "reply_to_sender",
        ]



        
class BusinessFollowSerializer(serializers.ModelSerializer):
    user = serializers.StringRelatedField(read_only=True)

    class Meta:
        model = BusinessFollow
        fields = [
            "id",
            "user",
            "business",
            "created_at",
        ]
        read_only_fields = [
            "id",
            "user",
            "created_at",
        ]


class CommunitySerializer(serializers.ModelSerializer):
    is_following = serializers.SerializerMethodField()
    is_member = serializers.SerializerMethodField()
    is_owner = serializers.SerializerMethodField()
    latest_post = serializers.SerializerMethodField()

    class Meta:
        model = BusinessProfile
        fields = ["id", "name", "logo", "description", "is_following", "is_member", "is_owner", "latest_post"]

    def _user(self):
        return self.context["request"].user

    def get_is_following(self, obj):
        return BusinessFollow.objects.filter(user=self._user(), business=obj).exists()

    def get_is_member(self, obj):
        user = self._user()
        return obj.user_id == user.id or CommunityMembership.objects.filter(
            user=user, business=obj
        ).exists()

    def get_is_owner(self, obj):
        return obj.user_id == self._user().id

    def get_latest_post(self, obj):
        user = self._user()
        if obj.user_id != user.id and not CommunityMembership.objects.filter(
            user=user,
            business=obj,
        ).exists():
            return None
        post = obj.community_posts.first()
        if post is None:
            return None
        return CommunityPostSerializer(post, context=self.context).data


class CommunityPostSerializer(serializers.ModelSerializer):
    business_name = serializers.CharField(source="business.name", read_only=True)
    author = serializers.CharField(source="author.username", read_only=True)
    media = serializers.FileField(required=False, allow_null=True)

    class Meta:
        model = CommunityPost
        fields = [
            "id", "business", "business_name", "author", "message",
            "media", "media_type", "created_at",
        ]
        read_only_fields = ["id", "business_name", "author", "created_at"]

    def validate(self, attrs):
        message = attrs.get("message", getattr(self.instance, "message", ""))
        media = attrs.get("media", getattr(self.instance, "media", None))
        media_type = attrs.get("media_type", getattr(self.instance, "media_type", ""))
        if not str(message or "").strip() and not media:
            raise serializers.ValidationError("Add a message, photo, or video to your update.")
        if media:
            if media.size > 50 * 1024 * 1024:
                raise serializers.ValidationError({"media": "Media must be 50 MB or smaller."})
            extension = media.name.rsplit(".", 1)[-1].lower() if "." in media.name else ""
            image_extensions = {"jpg", "jpeg", "png", "gif", "webp"}
            video_extensions = {"mp4", "mov", "webm", "m4v"}
            expected_type = (
                "image" if extension in image_extensions
                else "video" if extension in video_extensions
                else None
            )
            if expected_type is None:
                raise serializers.ValidationError({"media": "Choose a supported image or video file."})
            if media_type and media_type != expected_type:
                raise serializers.ValidationError({"media_type": "The selected media type does not match the file."})
            attrs["media_type"] = expected_type
        else:
            attrs["media_type"] = ""
        return attrs

class NotificationSerializer(serializers.ModelSerializer):
    sender = serializers.StringRelatedField(read_only=True)

    class Meta:
        model = Notification
        fields = [
            "id",
            "sender",
            "conversation",
            "notification_type",
            "message",
            "is_read",
            "created_at",
        ]
        read_only_fields = [
            "id",
            "sender",
            "conversation",
            "notification_type",
            "message",
            "created_at",
        ]

class SearchSerializer(serializers.Serializer):
    products = ProductSerializer(many=True)
    businesses = BusinessProfileSerializer(many=True)


class HomeFeedSerializer(serializers.Serializer):
    recommended = ProductSerializer(many=True)
    popular = ProductSerializer(many=True)
    new_arrivals = ProductSerializer(many=True)
    following = ProductSerializer(many=True)
    all_listings = ProductSerializer(many=True)

class RecentlyViewedSerializer(serializers.ModelSerializer):
    product = ProductSerializer(read_only=True)

    class Meta:
        model = ProductView
        fields = [
            "id",
            "product",
            "viewed_at",
        ]

class ReportSerializer(serializers.ModelSerializer):
    reporter = serializers.StringRelatedField(read_only=True)
    product_name = serializers.CharField(
        source="product.name",
        read_only=True,
        allow_null=True,
    )
    business_name = serializers.CharField(
        source="business.name",
        read_only=True,
        allow_null=True,
    )
    product_details = ProductSerializer(source="product", read_only=True)
    business_details = serializers.SerializerMethodField()

    class Meta:
        model = Report
        fields = [
            "id",
            "report_type",
            "product",
            "product_name",
            "product_details",
            "business",
            "business_name",
            "business_details",
            "reason",
            "reporter",
            "created_at",
            "review_status",
            "reviewed_at",
            "reviewed_by",
        ]

        read_only_fields = [
            "id",
            "created_at",
            "review_status",
            "reviewed_at",
            "reviewed_by",
        ]

    def get_business_details(self, obj):
        business = obj.business
        if business is None and obj.product_id:
            business = obj.product.business
        if business is None:
            return None

        logo = business.logo.url if business.logo else None
        request = self.context.get("request")
        if logo and request is not None:
            logo = request.build_absolute_uri(logo)

        return {
            "id": business.id,
            "name": business.name,
            "description": business.description,
            "logo": logo,
            "owner": business.user.username,
            "school": business.school.name,
            "is_suspended": business.is_suspended,
        }

    def validate(self, attrs):
        report_type = attrs.get(
            "report_type",
            getattr(self.instance, "report_type", None),
        )
        product = attrs.get("product", getattr(self.instance, "product", None))
        business = attrs.get("business", getattr(self.instance, "business", None))

        if report_type == Report.PRODUCT:
            if product is None:
                raise serializers.ValidationError(
                    {"product": "Choose the product you are reporting."}
                )
            if business is not None:
                raise serializers.ValidationError(
                    {"business": "A product report cannot include a business."}
                )
        elif report_type == Report.BUSINESS:
            if business is None:
                raise serializers.ValidationError(
                    {"business": "Choose the business you are reporting."}
                )
            if product is not None:
                raise serializers.ValidationError(
                    {"product": "A business report cannot include a product."}
                )
        else:
            raise serializers.ValidationError(
                {"report_type": "Choose product or business."}
            )

        reason = attrs.get("reason", getattr(self.instance, "reason", ""))
        if not reason.strip():
            raise serializers.ValidationError(
                {"reason": "Explain why you are reporting this."}
            )

        return attrs

 

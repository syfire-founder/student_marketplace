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
from .models import Review

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
            "description",
            "category",
            "category_name",
            "school",
            "school_name",
        ]
        read_only_fields = [
            "id",
            "school",
            "school_name",
        ]
        """
    
    def create(self, validated_data):
        #user will come from the view
        return BusinessProfile.objects.create(**validated_data)
        """
    """
    def validate(self, attrs):
        user = self.context['request'].user
        #only enforce on create not update
        if self.instance is None and BusinessProfile.objects.filter(user=user).exists():
            raise serializers.ValidationError("User already has a business.")
        return attrs
    """
    


class UserRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

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

    business_name = serializers.CharField(
        source="business.name",
        read_only=True
    )

    category = serializers.IntegerField(
        source="business.category.id",
        read_only=True
    )

    category_name = serializers.CharField(
        source="business.category.name",
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
            "category",
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
    class Meta:
        model = ProductFavorite
        fields = [
            "id",
            "product",
            "created_at",
        ]
        read_only_fields = [
            "id",
            "created_at",
        ]


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
    school_name = serializers.CharField(
        source="school.name",
        read_only=True
    )

    class Meta:
        model = UserProfile
        fields = [
            "id",
            "school",
            "school_name",
        ]
        read_only_fields = [
            "id",
            "school_name",
        ]





class ReviewSerializer(serializers.ModelSerializer):
    user = serializers.StringRelatedField(read_only=True)

    class Meta:
        model = Review
        fields = [
            "id",
            "business",
            "user",
            "rating",
            "comment",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "user",
            "created_at",
            "updated_at",
        ]

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
#Don't allow clients to set business
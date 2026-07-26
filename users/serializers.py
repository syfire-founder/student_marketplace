from rest_framework import serializers
from .models import BusinessProfile, Product
from .models import ListingImage
from .models import Category
from django.contrib.auth.models import User
from .models import School


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
    class Meta:
        model = BusinessProfile
        fields = ['name', 'description', 'category', 'school',]
        read_only_fields = ['id', "created_at"]
    
    def create(self, validated_data):
        #user will come from the view
        return BusinessProfile.objects.create(**validated_data)
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

    class Meta:
        model = User
        fields = ('username', 'email', 'password')

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email'),
            password=validated_data['password']
        )
        return user

class ListingImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ListingImage
        fields = '__all__'
    def validate_image(self, value):
        if value.size > 2 * 1024 * 1024:
            raise serializers.ValidationError("Image too large")
        return value
    


class ProductSerializer(serializers.ModelSerializer):

    images = ListingImageSerializer(many=True, read_only=True)
    class Meta:
        model = Product
        fields = "__all__"
        read_only_fields = ["business"]
            
        

class SchoolSerializer(serializers.ModelSerializer):
    class Meta:
        model = School
        fields = '__all__'

#Don't allow clients to set business
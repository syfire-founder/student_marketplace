from rest_framework import serializers
from .models import BusinessProfile, Product
from .models import Category
from django.contrib.auth.models import User



class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = '__all__'
    
class BusinessProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = BusinessProfile
        fields = ['id', 'business_name', 'business_category','created_at',]
        read_only_fields = ['id', "created_at"]
    
    def create(self, validated_data):
        #user will come from the view
        return BusinessProfile.objects.create(**validated_data)
    
    def validate(self, attrs):
        user = self.context['request'].user
        #only enforce on create not update
        if self.instance is None and hasattr(user, "business"):
            raise serializers.ValidationError("User already has a business.")
        return attrs
    
    


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
    


class ProductSerializer(serializers.ModelSerializer):
        class Meta:
            model = Product
            fields = "__all__"
            read_only_fields = ["business"]
#Don't allow clients to set business

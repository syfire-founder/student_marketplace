from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.filters import SearchFilter
from rest_framework.exceptions import ValidationError

from .models import BusinessProfile, Product
from .serializers import BusinessProfileSerializer, ProductSerializer, ListingImageSerializer

from rest_framework import generics, permissions
from .models import Category
from .serializers import CategorySerializer
from rest_framework.generics import ListAPIView
from rest_framework.generics import RetrieveUpdateDestroyAPIView
from rest_framework.authtoken.models import Token
from rest_framework.response import Response
from django.contrib.auth.models import User
from .serializers import UserRegisterSerializer
from .permissions import IsOwnerOrReadOnly, IsBusinessOwnerOrReadOnly
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticatedOrReadOnly
from rest_framework.viewsets import ModelViewSet
from .models import UserProfile
from django.db.models import Q
from django_filters.rest_framework import DjangoFilterBackend
from .models import ListingImage
from django.shortcuts import get_object_or_404
from rest_framework.permissions import AllowAny, IsAdminUser
from .models import School
from .serializers import SchoolSerializer
from .permissions import IsBusinessOwner










# import here
class BusinessProfileDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = BusinessProfile.objects.all()
    serializer_class = BusinessProfileSerializer
    permission_classes = [IsAuthenticated, IsOwnerOrReadOnly]
    
    

class BusinessProfileViewSet(viewsets.ModelViewSet):
    serializer_class = BusinessProfileSerializer
    filter_backends = [SearchFilter]
    search_fields = ["name", "description"]
    ordering_fields = ["name", "id"]
    ordering = ["-id"]

    def get_queryset(self):
        return BusinessProfile.objects.all()

    def get_permissions(self):
        if self.request.method in ["GET", "HEAD", "OPTIONS"]:
            return [AllowAny()]

        if self.request.method == "POST":
            return [IsAuthenticated()]

        return [IsAuthenticated(), IsBusinessOwner()]

    def perform_create(self, serializer):
        if BusinessProfile.objects.filter(user=self.request.user).exists():
            raise ValidationError(
                "You already have a business profile."
            )

        serializer.save(user=self.request.user)
    
class BusinessProfileSearchViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Allows searching other users' business profiles.
    Users cannot edit/delete others' profiles here
    """
    queryset = BusinessProfile.objects.all()
    serializer_class = BusinessProfileSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [SearchFilter]
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'id']
    ordering = ["-id"]


class CategoryListView(ListAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    
class CategoryListCreateView(generics.ListCreateAPIView):
    queryset = Category.objects.all().order_by("id")
    serializer_class = CategorySerializer

    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAdminUser()]

class CategoryRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer

    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAdminUser()]

class CategoryRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [IsAuthenticated]


class BusinessProfileListCreateView(generics.ListCreateAPIView):
    serializer_class = BusinessProfileSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # optional : limit to users own businesws profile only
        return BusinessProfile.objects.all()

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class BusinessProfileRetriveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    queryset = BusinessProfile.objects.all()
    serializer_class = BusinessProfileSerializer
    permission_classes = [IsAuthenticated]


    def perform_update(self, serializer):
        serializer.save(owner=self.request.user)



class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = UserRegisterSerializer
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        response = super().create(request, *args, **kwargs)
        user = User.objects.get(username=response.data['username'])
        token, _ = Token.objects.get_or_create(user=user)
        return Response({
            'user': response.data,
            'token': token.key
        })



class ProductViewSet(viewsets.ModelViewSet):
    serializer_class = ProductSerializer
    permission_classes = [IsAuthenticatedOrReadOnly, IsOwnerOrReadOnly]


    def get_queryset(self):
        user = self.request.user

        queryset = Product.objects.select_related(
            "business",
            "business__school",
            "business__user"
        )

        if not user.is_authenticated:
            return queryset.filter(is_private=False)

        try:
            user_school = user.userprofile.school
        except UserProfile.DoesNotExist:
            return queryset.filter(is_private=False)

        filtered = queryset.filter(
            Q(
                is_private=False,
                business__school=user_school
            )
            |
            Q(business__user=user)
        ).distinct()
        
        print("USER:", user)
        print("USER SCHOOL:", user_school)
        print("RESULT PRODUCTS:", list(filtered.values_list("name", flat=True)))
    
        return filtered





    """
    def get_queryset(self):
        user = self.request.user
       

        queryset = Product.objects.select_related(
            "business",
            "business__school",
            "business__user"
        )
        # anonymous users
        if not user.is_authenticated:
            return queryset.filter(is_private=False)

        try:
            user_school = user.userprofile.school
        except UserProfile.DoesNotExist:
            return queryset.filter(is_private=False)
            
        return queryset.filter(
            Q(
                is_private=False,
                business__school=user_school
            )
            |
            Q(business__user=user)
        ).distinct()


        min_price = self.request.query_params.get("min_price")
        max_price = self.request.query_params.get("max_price")

        if min_price:
            queryset = queryset.filter(price__gte=min_price)

        if max_price:
            query = queryset.filter(price__lte=max_price)
        
        return queryset

    """


    

    filter_backends = [DjangoFilterBackend, SearchFilter]

    filterset_fields = [
        "listing_type",
        "business__category",
        "is_available",
    ]

    search_fields = [
        "name",
        "description",
        "business__name",
        "business__category__name"
    ]
    
    ordering_fields = ["price", "created_at"]
    ordering = ["-created_at"]

    def perform_create(self, serializer):
        try:
            business = self.request.user.businessprofile
        except BusinessProfile.DoesNotExist:
            raise PermissionDenied("You do not have a business profile.")

        serializer.save(business=business)




class ListingImageViewSet(viewsets.ModelViewSet):

    serializer_class = ListingImageSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return ListingImage.objects.filter(product__business__user=self.request.user)
       # return ListingImage.objects.all()

    def perform_create(self, serializer):

        product_id = self.request.data.get("product")

        product = get_object_or_404(Product, id=product_id)

        #product = Product.objects.get(id=product_id)

        if product.business.user != self.request.user:
            raise PermissionDenied("You cannot upload images to this listing.")

        if product.images.count() >= 5:
            raise PermissionDenied("Maximum 5 images allowed.")

        serializer.save(product=product)




class SchoolViewSet(ModelViewSet):
    queryset = School.objects.all().order_by("name")
    serializer_class = SchoolSerializer

    def get_permissions(self):
        if self.request.method in ["GET", "HEAD", "OPTIONS"]:
            return [AllowAny()]
        return [IsAdminUser()]

"""
class ProductViewSet(viewsets.ModelViewSet):
    serializer_class = ProductSerializer
    permission_classes = [IsAuthenticatedOrReadOnly, IsOwnerOrReadOnly]


    
    def get_queryset(self):
        user = self.request.user

        if user.is_authenticated:
            queryset = queryset.filter(
                Q(is_private=False) |
                Q(business__user=user)
            ).distinct()
        else:
            queryset = queryset.filter(is_private=False)


        


        #Category filtering
        category_id = self.request.query_params.get("category")
        if category_id:
            queryset.filter(business__category_id=category_id)

        return Product.objects.filter(is_private=False)
            
        
    def perform_create(self, serializer):
       try:
        business = self.request.user.businessprofile
       except:
        raise PermissionDenied("You do not have a business profile.")



       serializer.save(business=business)
       """
from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.filters import SearchFilter
from rest_framework.exceptions import ValidationError

from .models import BusinessProfile, Product
from .serializers import BusinessProfileSerializer, ProductSerializer

from rest_framework import generics, permissions
from .models import Category
from .serializers import CategorySerializer
from rest_framework.generics import ListAPIView
from rest_framework.generics import RetrieveUpdateDestroyAPIView
from rest_framework.authtoken.models import Token
from rest_framework.response import Response
from django.contrib.auth.models import User
from .serializers import UserRegisterSerializer
from .permisions import IsOwnerOrReadOnly, IsBusinessOwnerOrReadOnly
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticatedOrReadOnly
from rest_framework.viewsets import ModelViewSet
from .models import Product
from django.db.models import Q










# import here
class BusinessProfileDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = BusinessProfile.objects.all()
    serializer_class = BusinessProfileSerializer
    permission_classes = [IsAuthenticated, IsOwnerOrReadOnly]
    
    

class BusinessProfileViewSet(viewsets.ModelViewSet):
    """
    CRUD for a user's own business profile
    -one profile per user
    -ownership enforced
    """
    serializer_class = BusinessProfileSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [SearchFilter]
    search_fields = ['name', 'description']
    ordering_fields = ["name", "id"]
    ordering = ["-id"]
#only logged-in users can access

    def get_queryset(self):
        #users can only see their own profile
        return BusinessProfile.objects.filter(user=self.request.user)
    
    def perform_create(self, serializer):
        #one profile per user - enforced at server level
        if BusinessProfile.objects.filter(user=self.request.user).exists():
            raise ValidationError("you already have a business profile")
        serializer.save(user=self.request.user)

    def get_object(self):
        # restrict put/ patch/ delete to the users profile"
        obj = super().get_object()
        if obj.user != self.request.user:
            raise ValidationError("you cannot access this profile(s)")
        return obj
    
    def get_queryset(self):
        #list only your own profile(S)
        return BusinessProfile.objects.filter(user=self.request.user)
    
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
    permission_classes = [IsAuthenticated]

class CategoryDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer

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

    def create(self, request, *args, **kwargs):
        response = super().create(request, *args, **kwargs)
        user = User.objects.get(username=response.data['username'])
        token, _ = Token.objects.get_or_create(user=user)
        return Response({
            'user': response.data,
            'token': token.key
        })
    



class ProductListCreateView(generics.ListCreateAPIView):
    serializer_class = ProductSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        return Product.objects.filter(business_user=user).order_by("id")

    def perform_create(self, serializer):
         
        user = self.request.user

        if not hasattr(user, "businessprofile"):
            raise PermissionDenied("You must have a business profile to create products.")

        serializer.save(business=user.businessprofile)

    




class ProductViewSet(viewsets.ModelViewSet):
    serializer_class = ProductSerializer
    permission_classes = [IsAuthenticatedOrReadOnly, IsOwnerOrReadOnly]


    def get_queryset(self):
        user = self.request.user

        #Anonymous users - only public products

        if not user.is_authenticated:
            return Product.objects.filter(is_public=True)
        
        #Authenticated users:
        # - see public products
        # - see their own products (public or private)
        return Product.objects.filter(
            Q(is_public=True) |
            Q(business_user=user)
        )

    def perform_create(self, serializer):
       try:
        business = self.request.user.businessprofile
       except:
        raise PermissionDenied("You do not have a business profile.")


       serializer.save(business=business)


class ProductDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ProductSerializer
    permission_classes = [permissions.IsAuthenticated, IsBusinessOwnerOrReadOnly]
    queryset = Product.objects.all()


class ProductRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    permission_classes = [IsBusinessOwnerOrReadOnly]


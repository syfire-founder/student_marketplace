from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.filters import SearchFilter
from rest_framework.exceptions import ValidationError

from .models import BusinessProfile
from .serializers import BusinessProfileSerializer

from rest_framework import generics, permissions
from .models import Category
from .serializers import CategorySerializer
from rest_framework.generics import ListAPIView
from rest_framework.generics import RetrieveUpdateDestroyAPIView






# import here
class BusinessProfileDetailView(RetrieveUpdateDestroyAPIView):
    serializer_class = BusinessProfileSerializer
    permission_classes = [IsAuthenticated]
    def get_queryset(self):
        user = self.request.user
        if user.is_staff:
            return BusinessProfile.objects.all()
        return BusinessProfile.objects.filter(user=user)
    

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
    queryset = BusinessProfile.objects.all()
    serializer_class = BusinessProfileSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class BusinessProfileRetriveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    queryset = BusinessProfile.objects.all()
    serializer_class = BusinessProfileSerializer
    permission_classes = [IsAuthenticated]


    def perform_update(self, serializer):
        serializer.save(owner=self.request.user)
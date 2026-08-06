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
from .serializers import SchoolSerializer, UserProfileSerializer
from .permissions import IsBusinessOwner
from .serializers import ReviewSerializer
from .models import Review
from .permissions import IsReviewOwner
from rest_framework.views import APIView
from django.db.models import Avg
from .models import ProductFavorite
from .serializers import BusinessDashboardSerializer
from .models import ProductView
from django.db.models import Count
from .models import Review
from django.utils import timezone
from datetime import timedelta
from rest_framework import status, viewsets
from django.db.models import Count
from django.shortcuts import get_object_or_404
from .models import Conversation, Message, BusinessFollow
from .serializers import ConversationSerializer, MessageSerializer
from .utils import create_notification
from .serializers import ProductFavoriteSerializer
from .serializers import BusinessFollowSerializer
from .utils import create_notification
from .models import Notification
from .serializers import NotificationSerializer, SearchSerializer, HomeFeedSerializer, RecentlyViewedSerializer
from .pagination import MarketplacePagination
from .models import Report
from .serializers import ReportSerializer

# import here
class UserProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserProfileSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user.userprofile


class BusinessProfileDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = BusinessProfile.objects.all()
    serializer_class = BusinessProfileSerializer
    permission_classes = [IsAuthenticated, IsOwnerOrReadOnly]
    
    

class BusinessProfileViewSet(viewsets.ModelViewSet):
    serializer_class = BusinessProfileSerializer
    pagination_class = MarketplacePagination
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

        try:
            profile = self.request.user.userprofile
        except UserProfile.DoesNotExist:
            raise ValidationError(
                "Please complete your profile before creating a business profile."
            )

        if profile.school is None:
            raise ValidationError(
                "Please select your school before creating a business profile."
            )

        serializer.save(
            user=self.request.user,
            school=profile.school
        )

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
    pagination_class = MarketplacePagination


    def get_queryset(self):
        user = self.request.user

        queryset = Product.objects.select_related(
            "business",
            "business__school",
            "business__user",
            ).prefetch_related(
                "images"
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
    
    ordering_fields = ["name", "price", "created_at"]
    ordering = ["-created_at"]

    def perform_create(self, serializer):
        try:
            business = self.request.user.businessprofile
        except BusinessProfile.DoesNotExist:
            raise PermissionDenied("You do not have a business profile.")

        serializer.save(business=business)

    def retrieve(self, request, *args, **kwargs):
        product = self.get_object()

        ProductView.objects.create(
            product=product,
            user=request.user if request.user.is_authenticated else None
        )

        serializer = self.get_serializer(product)

        return Response(serializer.data)




class ListingImageViewSet(viewsets.ModelViewSet):

    serializer_class = ListingImageSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return ListingImage.objects.filter(product__business__user=self.request.user)
       # return ListingImage.objects.all()

    def perform_create(self, serializer):
        
        product_id = self.request.data.get("product")

        if not product_id:
            raise ValidationError(
                "Product is required."
            )

        product = get_object_or_404(
            Product,
            id=product_id
        )

        if product.business.user != self.request.user:
            raise PermissionDenied(
                "You cannot upload images to this listing."
            )
        
        if product.images.count() >= 5:
            raise ValidationError(
                "Maximum 5 images allowed."
            )

        serializer.save(product=product)




class SchoolViewSet(ModelViewSet):
    queryset = School.objects.all().order_by("name")
    serializer_class = SchoolSerializer

    def get_permissions(self):
        if self.request.method in ["GET", "HEAD", "OPTIONS"]:
            return [AllowAny()]
        return [IsAdminUser()]



class ReviewViewSet(viewsets.ModelViewSet):
    serializer_class = ReviewSerializer
    queryset = Review.objects.select_related(
        "user",
        "business"
    )
    pagination_class = MarketplacePagination

    def get_permissions(self):
        if self.request.method in ["GET", "HEAD", "OPTIONS"]:
            return [AllowAny()]

        if self.request.method == "POST":
            return [IsAuthenticated()]

        return [IsAuthenticated(), IsReviewOwner()]

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class BusinessDashboardView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            business = request.user.businessprofile
        except BusinessProfile.DoesNotExist:
            raise ValidationError(
                "You do not have a business profile."
            )

        top_products = (
            business.products
            .annotate(view_count=Count("views"))
            .order_by("-view_count", "-created_at")[:5]
        )

        last_week = timezone.now() - timedelta(days=7)

        trending_products = (
            business.products
            .annotate(
                views_last_7_days=Count(
                    "views",
                    filter=Q(
                        views__viewed_at__gte=last_week
                        )
                    )
                )
                .order_by("-views_last_7_days")[:5]
            )

        recent_reviews = (
            Review.objects
            .filter(business=business)
            .select_related("user")
            .order_by("-created_at")[:5]
        )

        data = {
            "business": business.name,
            "followers": business.followers.count(),
            "products": business.products.count(),
            "reviews": Review.objects.filter(
                business=business
            ).count(),
            "average_rating": (
                Review.objects.filter(
                    business=business
                ).aggregate(
                    Avg("rating")
                )["rating__avg"] or 0
            ),
            "favorites": ProductFavorite.objects.filter(
                product__business=business
            ).count(),
            "total_views": ProductView.objects.filter(
                product__business=business
            ).count(),
            "top_products": [
                {
                    "id": product.id,
                    "name": product.name,
                    "views": product.view_count,
                }
                for product in top_products
            ],
            "trending_products": [
                {
                    "id": product.id,
                    "name": product.name,
                    "views_last_7_days": product.views_last_7_days,
                    }
                    for product in trending_products
                ],
            "recent_reviews": [
                {
                    "user": review.user.username,
                    "rating": review.rating,
                    "comment": review.comment,
                    "created_at": review.created_at,
                }
                for review in recent_reviews
                ],
        }

        serializer = BusinessDashboardSerializer(instance=data)

        return Response(serializer.data)


class ConversationViewSet(viewsets.ModelViewSet):
    serializer_class = ConversationSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = MarketplacePagination

    def get_queryset(self):
        return (
            Conversation.objects
            .filter(participants=self.request.user)
            .prefetch_related("participants")
            .order_by("-updated_at")
        )

    def create(self, request, *args, **kwargs):
        participant_ids = request.data.get("participants", [])

        if len(participant_ids) != 1:
            raise ValidationError(
                "Provide exactly one user to start a conversation."
            )

        other_user = get_object_or_404(
            User,
            id=participant_ids[0]
        )

        if other_user == request.user:
            raise ValidationError(
                "You cannot start a conversation with yourself."
            )

        existing = (
            Conversation.objects
            .filter(participants=request.user)
            .filter(participants=other_user)
            .annotate(num_participants=Count("participants"))
            .filter(num_participants=2)
            .first()
        )

        if existing:
            serializer = self.get_serializer(existing)
            return Response(serializer.data)

        conversation = Conversation.objects.create()

        conversation.participants.add(
            request.user,
            other_user
        )

        serializer = self.get_serializer(conversation)

        return Response(
            serializer.data,
            status=status.HTTP_201_CREATED
        )

class MessageViewSet(viewsets.ModelViewSet):
    serializer_class = MessageSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = MarketplacePagination

    def get_queryset(self):
        return (
            Message.objects
            .filter(conversation__participants=self.request.user)
            .select_related("sender", "conversation")
            .order_by("created_at")
        )

    def perform_create(self, serializer):
        conversation_id = self.request.data.get("conversation")

        conversation = get_object_or_404(
            Conversation,
            id=conversation_id
        )

        if not conversation.has_participant(self.request.user):
            raise PermissionDenied(
                "You are not a participant in this conversation."
            )

        message = serializer.save(
            sender=self.request.user,
            conversation=conversation
            )
            #
        print("Sender:", self.request.user)

        recipient = conversation.participants.exclude(
            id=self.request.user.id
            ).first()
        print("Recipient:", recipient)

        create_notification(
            recipient=recipient,
            sender=self.request.user,
            notification_type=Notification.MESSAGE,
            message=f"{self.request.user.username} sent you a message."
            )
        print("Notification attempted")

    def perform_update(self, serializer):
        if serializer.instance.sender != self.request.user:
            raise PermissionDenied(
                "You can only edit your own messages."
            )

        serializer.save()

    def perform_destroy(self, instance):
        if instance.sender != self.request.user:
            raise PermissionDenied(
                "You can only delete your own messages."
            )

        instance.delete()



class ProductFavoriteViewSet(viewsets.ModelViewSet):
    serializer_class = ProductFavoriteSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = MarketplacePagination

    def get_queryset(self):
        return ProductFavorite.objects.filter(
            user=self.request.user
        ).select_related("product")

    def perform_create(self, serializer):
        product_id = self.request.data.get("product")

        product = get_object_or_404(
            Product,
            id=product_id
        )

        if ProductFavorite.objects.filter(
            user=self.request.user,
            product=product
        ).exists():
            raise ValidationError(
                "You have already favorited this product."
            )

        serializer.save(
            user=self.request.user,
            product=product
        )

class BusinessFollowViewSet(viewsets.ModelViewSet):
    serializer_class = BusinessFollowSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = MarketplacePagination

    def get_queryset(self):
        return BusinessFollow.objects.filter(
            user=self.request.user
        ).select_related("business")

    def perform_create(self, serializer):
        business_id = self.request.data.get("business")

        business = get_object_or_404(
            BusinessProfile,
            id=business_id
        )

        if business.user == self.request.user:
            raise ValidationError(
                "You cannot follow your own business."
            )

        if BusinessFollow.objects.filter(
            user=self.request.user,
            business=business
        ).exists():
            raise ValidationError(
                "You are already following this business."
            )

        follow = serializer.save(
            user=self.request.user,
            business=business
        )

        create_notification(
            recipient=business.user,
            sender=self.request.user,
            notification_type=Notification.FOLLOW,
            message=f"{self.request.user.username} followed your business."
        )




class NotificationViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = MarketplacePagination

    def get_queryset(self):
        return Notification.objects.filter(
            recipient=self.request.user
        ).select_related("sender")

    def get_permissions(self):
        if self.action in ["list", "retrieve", "partial_update"]:
            return [IsAuthenticated()]
        return [IsAdminUser()]

    def perform_update(self, serializer):
        serializer.save()


class UnreadNotificationCountView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        count = Notification.objects.filter(
            recipient=request.user,
            is_read=False
        ).count()

        return Response({
            "unread_count": count
        })

class SearchView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # 1. Read query parameters
        query = request.query_params.get("q", "").strip()
        category = request.query_params.get("category")
        listing_type = request.query_params.get("listing_type")
        min_price = request.query_params.get("min_price")
        max_price = request.query_params.get("max_price")
        ordering = request.query_params.get("ordering")

        # 2. Get the user's school
        try:
            school = request.user.userprofile.school
        except UserProfile.DoesNotExist:
            return Response(
                {"detail": "User profile not found."},
                status=404
             )

        if school is None:
            return Response(
                {"detail": "Please select a school first."},
                status=400
            )

        # 3. Base queryset
        products = Product.objects.filter(
            business__school=school,
            is_private=False,
            is_available=True,
        )

        # 4. Search text
        if query:
            products = products.filter(
                Q(name__icontains=query) |
                Q(description__icontains=query) |
                Q(category__name__icontains=query) |
                Q(business__name__icontains=query)
            )

        # 5. Extra filters
        if category:
            products = products.filter(category_id=category)

        if listing_type:
            products = products.filter(listing_type=listing_type)

        if min_price:
            products = products.filter(price__gte=min_price)

        if max_price:
            products = products.filter(price__lte=max_price)

        allowed_ordering = [
            "price",
            "-price",
            "created_at",
            "-created_at",
        ]

        if ordering in allowed_ordering:
            products = products.order_by(ordering)
        else:
            products = products.order_by("-created_at")
        # 6. Businesses
        businesses = BusinessProfile.objects.filter(
            school=school
        )
        if query:
            businesses = businesses.filter(
                Q(name__icontains=query) |
                Q(description__icontains=query) |
                Q(category__name__icontains=query)
            )

        # 7. Return response
        serializer = SearchSerializer({
            "products": products.distinct(),
            "businesses": businesses.distinct(),
        })

        return Response(serializer.data)


class HomeFeedView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            school = request.user.userprofile.school
        except UserProfile.DoesNotExist:
            return Response(
                {"detail": "User profile not found."},
                status=404
            )

        if school is None:
            return Response(
                {"detail": "Please select a school first."},
                status=400
            )
        products = Product.objects.filter(
            business__school=school,
            is_available=True,
            is_private=False
            )
        new_arrivals = products.order_by("-created_at")[:10]
        popular = (
            products
            .annotate(
                num_views=Count("views")
            )
            .order_by("-num_views", "-created_at")[:10]
        )
        followed_businesses = BusinessFollow.objects.filter(
            user=request.user
            ).values_list(
                "business_id",
                flat=True
            )

        following = products.filter(
            business_id__in=followed_businesses
        ).order_by("-created_at")[:10]

        recommended = (
            products
            .annotate(
                avg_rating=Avg("business__reviews__rating"),
                num_views=Count("views", distinct=True),
            )
            .order_by(
                "-avg_rating",
                "-num_views",
                "-created_at",
            )[:10]
        )
        
        serializer = HomeFeedSerializer({
            "recommended": recommended,
            "popular": popular,
            "new_arrivals": new_arrivals,
            "following": following,
        })
        
        return Response(serializer.data)

class RecentlyViewedView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        views = (
            ProductView.objects
            .filter(user=request.user)
            .select_related(
                "product",
                "product__business",
                "product__category",
            )
            .order_by("-viewed_at")
        )

        serializer = RecentlyViewedSerializer(
            views,
            many=True
        )

        return Response(serializer.data)

class ReportViewSet(viewsets.ModelViewSet):
    serializer_class = ReportSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Report.objects.filter(
            reporter=self.request.user
        )

    def perform_create(self, serializer):
        serializer.save(
            reporter=self.request.user
        )
"""

class SearchView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        products = Product.objects.all()
        
        query = request.query_params.get("q", "").strip()

        if not query:
            return Response({
                "products": [],
                "businesses": []
            })

    

        school = request.user.userprofile.school

        products = (
            Product.objects
            .filter(
                business__school=school,
                is_private=False,
                is_available=True,
            )
            .filter(
                Q(name__icontains=query) |
                Q(description__icontains=query) |
                Q(category__name__icontains=query) |
                Q(business__name__icontains=query)
            )
            .select_related(
                "business",
                "category",
            )
            .distinct()
        )

        businesses = (
            BusinessProfile.objects
            .filter(
                school=school
            )
            .filter(
                Q(name__icontains=query) |
                Q(description__icontains=query) |
                Q(category__name__icontains=query)
            )
            .distinct()
        )

        serializer = SearchSerializer({
            "products": products,
            "businesses": businesses,
        })

        return Response(serializer.data)
"""
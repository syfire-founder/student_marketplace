from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.filters import SearchFilter
from rest_framework.exceptions import ValidationError
from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.mail import send_mail
import logging
import secrets

from .models import (
    BusinessProfile, BusinessProfileVisit, Product, AppVisit, PendingRegistration,
    AccountRecoveryCode,
)
from .serializers import BusinessProfileSerializer, ProductSerializer, ListingImageSerializer

from rest_framework import generics, permissions
from .models import Category
from .serializers import CategorySerializer
from rest_framework.generics import ListAPIView
from rest_framework.generics import RetrieveUpdateDestroyAPIView
from rest_framework.authtoken.models import Token
from rest_framework.response import Response
from django.contrib.auth.models import User
from django.contrib.auth import authenticate
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
from django.db.models.functions import TruncDate
from .models import Review
from django.utils import timezone
from datetime import timedelta
from rest_framework import status, viewsets
from rest_framework.decorators import action
from django.db.models import Count
from django.shortcuts import get_object_or_404
from .models import (
    Conversation, Message, BusinessFollow, ConversationPair,
    CommunityMembership, CommunityPost,
)
from .serializers import (
    ConversationSerializer, MessageSerializer,
    CommunitySerializer, CommunityPostSerializer,
)
from .utils import create_notification
from .serializers import ProductFavoriteSerializer
from .serializers import BusinessFollowSerializer
from .utils import create_notification
from .models import Notification
from .serializers import NotificationSerializer, SearchSerializer, HomeFeedSerializer, RecentlyViewedSerializer
from .pagination import MarketplacePagination
from .models import Report
from .serializers import ReportSerializer
from django.db import transaction, IntegrityError
from django.http import FileResponse
import mimetypes


logger = logging.getLogger(__name__)


def _create_email_code():
    return f"{secrets.randbelow(1_000_000):06d}"


def _send_short_email(to_email, subject, message):
    if not settings.EMAIL_NOTIFICATIONS_ENABLED:
        return True
    if not to_email:
        return False
    try:
        send_mail(
            subject,
            message,
            settings.DEFAULT_FROM_EMAIL,
            [to_email],
            fail_silently=False,
        )
        return True
    except Exception:
        logger.exception("Could not send an application email to %s", to_email)
        return False


def _get_or_create_direct_conversation(first_user, second_user):
    if first_user.id == second_user.id:
        return None

    user_low_id, user_high_id = sorted([first_user.id, second_user.id])
    pair = ConversationPair.objects.filter(
        user_low_id=user_low_id,
        user_high_id=user_high_id,
    ).select_related("conversation").first()
    if pair is not None:
        return pair.conversation

    conversation = Conversation.objects.create()
    conversation.participants.add(first_user, second_user)
    try:
        with transaction.atomic():
            pair = ConversationPair.objects.create(
                user_low_id=user_low_id,
                user_high_id=user_high_id,
                conversation=conversation,
            )
    except IntegrityError:
        conversation.delete()
        pair = ConversationPair.objects.select_related("conversation").get(
            user_low_id=user_low_id,
            user_high_id=user_high_id,
        )
    return pair.conversation


def _send_inbox_message(sender, recipient, text):
    conversation = _get_or_create_direct_conversation(sender, recipient)
    if conversation is None:
        return False

    Message.objects.create(
        conversation=conversation,
        sender=sender,
        text=text,
    )
    create_notification(
        recipient=recipient,
        sender=sender,
        notification_type=Notification.MESSAGE,
        message="You received a message from the BluuBase team.",
        conversation=conversation,
    )
    return True

# import here
class UserProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserProfileSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user.userprofile



class BusinessProfileViewSet(viewsets.ModelViewSet):
    serializer_class = BusinessProfileSerializer
    pagination_class = MarketplacePagination
    filter_backends = [SearchFilter]
    search_fields = ["name", "description"]
    ordering_fields = ["name", "id"]
    ordering = ["-id"]

    def get_queryset(self):
        queryset = BusinessProfile.objects.all()
        user = self.request.user
        if user.is_staff:
            return queryset
        if user.is_authenticated:
            return queryset.filter(Q(is_suspended=False) | Q(user=user))
        return queryset.filter(is_suspended=False)

    @action(
        detail=False,
        methods=["get"],
        url_path="mine",
        permission_classes=[IsAuthenticated],
    )
    def mine(self, request):
        business = self.get_queryset().filter(user=request.user).first()
        if business is None:
            return Response(
                {"detail": "You do not have a business profile yet."},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(self.get_serializer(business).data)

    def get_permissions(self):
        if getattr(self, "action", None) == "mine":
            return [IsAuthenticated()]

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

        business = serializer.save(
            user=self.request.user,
            school=profile.school
        )
        _send_short_email(
            self.request.user.email,
            "Your BluuBase business profile is ready",
            f"Hi {self.request.user.username}, your business profile “{business.name}” "
            "has been created. You can now add products or services for students to find.",
        )

    def retrieve(self, request, *args, **kwargs):
        business = self.get_object()
        if request.user.is_authenticated:
            BusinessProfileVisit.objects.update_or_create(
                user=request.user,
                business=business,
                defaults={"viewed_at": timezone.now()},
            )
        return Response(self.get_serializer(business).data)

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






class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = UserRegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        username = serializer.validated_data["username"].strip()
        email = serializer.validated_data["email"].strip().lower()
        password = serializer.validated_data["password"]
        school = serializer.validated_data["school"]

        if User.objects.filter(email__iexact=email).exists():
            raise ValidationError({"email": "An account already uses this email."})
        try:
            validate_password(password, user=User(username=username, email=email))
        except DjangoValidationError as error:
            raise ValidationError({"password": error.messages})

        if not settings.REQUIRE_EMAIL_VERIFICATION:
            with transaction.atomic():
                serializer.validated_data["username"] = username
                serializer.validated_data["email"] = email
                user = serializer.save()
                token, _ = Token.objects.get_or_create(user=user)
            return Response(
                {"token": token.key, "is_admin": False},
                status=status.HTTP_201_CREATED,
            )

        if not settings.EMAIL_NOTIFICATIONS_ENABLED:
            return Response(
                {"detail": "Email verification is not available right now."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        now = timezone.now()
        PendingRegistration.objects.filter(expires_at__lte=now).delete()
        pending = PendingRegistration.objects.filter(email__iexact=email).first()
        if pending is None:
            pending = PendingRegistration.objects.filter(username__iexact=username).first()
        if pending is not None:
            email_conflict = PendingRegistration.objects.filter(
                email__iexact=email
            ).exclude(pk=pending.pk).exists()
            if email_conflict:
                raise ValidationError({"email": "A registration is already pending for this email."})
            if (now - pending.last_sent_at).total_seconds() < 60:
                return Response(
                    {"detail": "A code was sent recently. Please check your email or wait before requesting another."},
                    status=status.HTTP_429_TOO_MANY_REQUESTS,
                )
        elif PendingRegistration.objects.filter(username__iexact=username).exists():
            raise ValidationError({"username": "A registration is already pending for this username."})

        code = _create_email_code()
        if pending is None:
            pending = PendingRegistration.objects.create(
                username=username,
                email=email,
                password_hash=make_password(password),
                school=school,
                code_hash=make_password(code),
                expires_at=now + timedelta(minutes=10),
                last_sent_at=now - timedelta(minutes=2),
            )
        else:
            pending.username = username
            pending.email = email
            pending.password_hash = make_password(password)
            pending.school = school
            pending.code_hash = make_password(code)
            pending.expires_at = now + timedelta(minutes=10)
            pending.attempts = 0
            pending.last_sent_at = now - timedelta(minutes=2)
            pending.save(update_fields=[
                "password_hash", "school", "code_hash", "expires_at",
                "attempts", "last_sent_at", "username", "email",
            ])

        sent = _send_short_email(
            email,
            "Your BluuBase registration code",
            f"Your BluuBase registration code is {code}. It expires in 10 minutes. "
            "If you did not request this, you can ignore this email.",
        )
        if not sent:
            return Response(
                {"detail": "We could not send your code right now. Please try again shortly."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        pending.last_sent_at = now
        pending.save(update_fields=["last_sent_at"])
        return Response(
            {"detail": "A registration code was sent to your email.", "expires_in_seconds": 600},
            status=status.HTTP_202_ACCEPTED,
        )


class VerifyRegistrationView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        if not settings.REQUIRE_EMAIL_VERIFICATION:
            return Response(
                {"detail": "Email verification is disabled for this test release."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        email = str(request.data.get("email", "")).strip().lower()
        code = str(request.data.get("code", "")).strip()
        if not email or not code:
            raise ValidationError({"detail": "Enter the email address and code."})

        with transaction.atomic():
            pending = PendingRegistration.objects.select_for_update().filter(
                email__iexact=email
            ).first()
            if pending is None:
                return Response({"detail": "The code is invalid or expired."}, status=400)
            if pending.expires_at <= timezone.now():
                pending.delete()
                return Response({"detail": "The code expired. Start registration again."}, status=400)
            if pending.attempts >= 5:
                pending.delete()
                return Response({"detail": "Too many incorrect attempts. Start registration again."}, status=400)
            if not check_password(code, pending.code_hash):
                pending.attempts += 1
                pending.save(update_fields=["attempts"])
                return Response({"detail": "The code is incorrect."}, status=400)

            user = User(
                username=pending.username,
                email=pending.email,
                password=pending.password_hash,
            )
            user.save(force_insert=True)
            UserProfile.objects.create(user=user, school=pending.school)
            token, _ = Token.objects.get_or_create(user=user)
            pending.delete()

        _send_short_email(
            user.email,
            "Welcome to BluuBase",
            f"Hi {user.username}, your BluuBase account is ready. You can now discover "
            "campus businesses, save listings, and message sellers.",
        )
        return Response(
            {"token": token.key, "is_admin": False},
            status=status.HTTP_201_CREATED,
        )


class ResendRegistrationCodeView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        if not settings.REQUIRE_EMAIL_VERIFICATION:
            return Response(
                {"detail": "Email verification is disabled for this test release."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        email = str(request.data.get("email", "")).strip().lower()
        pending = PendingRegistration.objects.filter(email__iexact=email).first()
        if pending is None:
            return Response({"detail": "No pending registration was found."}, status=404)
        now = timezone.now()
        if (now - pending.last_sent_at).total_seconds() < 60:
            return Response(
                {"detail": "Please wait before requesting another code."},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )
        code = _create_email_code()
        pending.code_hash = make_password(code)
        pending.expires_at = now + timedelta(minutes=10)
        pending.attempts = 0
        pending.save(update_fields=["code_hash", "expires_at", "attempts"])
        if not _send_short_email(
            email,
            "Your new BluuBase registration code",
            f"Your new BluuBase registration code is {code}. It expires in 10 minutes.",
        ):
            return Response(
                {"detail": "We could not send your code right now. Please try again shortly."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        pending.last_sent_at = now
        pending.save(update_fields=["last_sent_at"])
        return Response({"detail": "A new code was sent to your email."})


class PasswordResetRequestView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        if not settings.EMAIL_NOTIFICATIONS_ENABLED:
            return Response(
                {"detail": "Password recovery by email is paused during testing."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        email = str(request.data.get("email", "")).strip().lower()
        user = User.objects.filter(email__iexact=email, is_staff=False).first()
        if user is not None:
            now = timezone.now()
            recovery, _ = AccountRecoveryCode.objects.get_or_create(
                user=user,
                defaults={
                    "code_hash": make_password(_create_email_code()),
                    "expires_at": now,
                    "last_sent_at": now - timedelta(minutes=2),
                },
            )
            if (now - recovery.last_sent_at).total_seconds() >= 60:
                code = _create_email_code()
                recovery.code_hash = make_password(code)
                recovery.expires_at = now + timedelta(minutes=10)
                recovery.attempts = 0
                recovery.save(update_fields=["code_hash", "expires_at", "attempts"])
                if _send_short_email(
                    user.email,
                    "Reset your BluuBase password",
                    f"Your BluuBase password reset code is {code}. It expires in 10 minutes. "
                    "If you did not request this, ignore this email.",
                ):
                    recovery.last_sent_at = now
                    recovery.save(update_fields=["last_sent_at"])
        return Response({
            "detail": "If an account uses that email, a password reset code will be sent shortly."
        })


class PasswordResetConfirmView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = str(request.data.get("email", "")).strip().lower()
        code = str(request.data.get("code", "")).strip()
        new_password = str(request.data.get("new_password", ""))
        recovery = AccountRecoveryCode.objects.select_related("user").filter(
            user__email__iexact=email,
            user__is_staff=False,
        ).first()
        if recovery is None or not code or not new_password:
            return Response({"detail": "The code is invalid or expired."}, status=400)
        if recovery.expires_at <= timezone.now() or recovery.attempts >= 5:
            recovery.delete()
            return Response({"detail": "The code is invalid or expired."}, status=400)
        if not check_password(code, recovery.code_hash):
            recovery.attempts += 1
            recovery.save(update_fields=["attempts"])
            return Response({"detail": "The code is incorrect."}, status=400)
        try:
            validate_password(new_password, user=recovery.user)
        except DjangoValidationError as error:
            raise ValidationError({"new_password": error.messages})

        with transaction.atomic():
            user = User.objects.select_for_update().get(pk=recovery.user_id)
            user.set_password(new_password)
            user.save(update_fields=["password"])
            Token.objects.filter(user=user).delete()
            recovery.delete()
        return Response({"detail": "Your password was reset. Please sign in with your new password."})


class RegularLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        user = authenticate(
            request,
            username=request.data.get("username"),
            password=request.data.get("password"),
        )
        if user is None:
            return Response(
                {"detail": "Incorrect username or password."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if user.is_staff:
            return Response(
                {"detail": "Use the administrator sign-in."},
                status=status.HTTP_403_FORBIDDEN,
            )
        token, _ = Token.objects.get_or_create(user=user)
        return Response({"token": token.key, "is_admin": False})


class AdminLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        user = authenticate(
            request,
            username=request.data.get("username"),
            password=request.data.get("password"),
        )
        if user is None:
            return Response(
                {"detail": "Incorrect administrator username or password."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not user.is_staff:
            return Response(
                {"detail": "This account is not an administrator account."},
                status=status.HTTP_403_FORBIDDEN,
            )
        token, _ = Token.objects.get_or_create(user=user)
        return Response({"token": token.key, "is_admin": True})



class ProductViewSet(viewsets.ModelViewSet):

    serializer_class = ProductSerializer
    permission_classes = [
        IsAuthenticatedOrReadOnly,
        IsOwnerOrReadOnly,
    ]
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
            return queryset.filter(
                is_private=False,
                business__is_suspended=False,
            )

        try:
            user_school = user.userprofile.school
        except UserProfile.DoesNotExist:
            return queryset.filter(
                is_private=False,
                business__is_suspended=False,
            )

        filtered = queryset.filter(
            Q(
                is_private=False,
                business__school=user_school,
                business__is_suspended=False,
            )
            |
            Q(
                business__user=user
            )
        ).distinct()

        print("USER:", user)
        print("USER SCHOOL:", user_school)
        print(
            "RESULT PRODUCTS:",
            list(filtered.values_list("name", flat=True))
        )

        return filtered

    def perform_create(self, serializer):
        try:
            business = self.request.user.businessprofile
        except BusinessProfile.DoesNotExist:
            raise PermissionDenied(
                "You do not have a business profile."
            )

        if business.is_suspended:
            raise PermissionDenied(
                "Your business profile is suspended, so you cannot add listings."
            )

        images = self.request.FILES.getlist("images")
        if not images:
            raise ValidationError({"images": "Add at least one listing photo."})
        if len(images) > 5:
            raise ValidationError({"images": "A listing can have up to 5 photos."})
        if any(image.size > 2 * 1024 * 1024 for image in images):
            raise ValidationError({"images": "Each photo must be under 2 MB."})

        with transaction.atomic():
            product = serializer.save(business=business)
            for image in images:
                ListingImage.objects.create(product=product, image=image)

    def retrieve(self, request, *args, **kwargs):
        product = self.get_object()

        ProductView.objects.create(
            product=product,
            user=request.user if request.user.is_authenticated else None
        )

        serializer = self.get_serializer(product)

        return Response(serializer.data)

    def get_permissions(self):
        print("CURRENT ACTION:", self.action)

        if self.action == "favorite":
            print("FAVORITE PERMISSION SELECTED")
            return [IsAuthenticated()]

        return super().get_permissions()

    @action(
        detail=True,
        methods=["get", "post", "delete"],
        url_path="favorite"
    )
    def favorite(self, request, pk=None):
        product = self.get_object()

        if request.method == "GET":
            is_favorite = ProductFavorite.objects.filter(
                user=request.user,
                product=product
            ).exists()

            return Response({
                "is_favorite": is_favorite
            })

        if request.method == "POST":
            favorite, created = ProductFavorite.objects.get_or_create(
                user=request.user,
                product=product
            )

            if not created:
                return Response(
                    {
                        "detail":
                        "You have already favorited this product."
                    },
                    status=400
                )

            return Response(
                {
                    "id": favorite.id,
                    "product": product.id,
                    "detail": "Product added to favorites."
                },
                status=201
            )

        deleted, _ = ProductFavorite.objects.filter(
            user=request.user,
            product=product
        ).delete()

        if deleted == 0:
            return Response(
                {
                    "detail": "Product is not in your favorites."
                },
                status=404
            )

        return Response(
            {"detail": "Product removed from favorites."},
            status=204
        )


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

    def get_queryset(self):
        queryset = self.queryset
        business_id = self.request.query_params.get("business")
        if business_id:
            try:
                business_id = int(business_id)
            except (TypeError, ValueError):
                return queryset.none()
            queryset = queryset.filter(business_id=business_id)
        return queryset

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

    @action(detail=False, methods=["get"], url_path="unread-count")
    def unread_count(self, request):
        count = Message.objects.filter(
            conversation__participants=request.user,
            is_read=False,
        ).exclude(sender=request.user).count()
        return Response({"unread_count": count})




    def create(self, request, *args, **kwargs):
        participant_ids = request.data.get("participants", [])

        if not isinstance(participant_ids, list) or len(participant_ids) != 1:
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

        user_low_id, user_high_id = sorted(
            [request.user.id, other_user.id]
        )

        with transaction.atomic():
            pair = ConversationPair.objects.filter(
                user_low_id=user_low_id,
                user_high_id=user_high_id,
            ).select_related("conversation").first()

            if pair:
                serializer = self.get_serializer(pair.conversation)
                return Response(serializer.data)

            conversation = Conversation.objects.create()
            conversation.participants.add(request.user, other_user)

            try:
                # Keep the unique-constraint failure inside a savepoint so
                # the surrounding transaction remains usable for recovery.
                with transaction.atomic():
                    ConversationPair.objects.create(
                        user_low_id=user_low_id,
                        user_high_id=user_high_id,
                        conversation=conversation,
                    )
            except IntegrityError:
                # Another request may have created this pair concurrently.
                conversation.delete()

                pair = ConversationPair.objects.select_related(
                    "conversation"
                ).get(
                    user_low_id=user_low_id,
                    user_high_id=user_high_id,
                )

                serializer = self.get_serializer(pair.conversation)
                return Response(serializer.data)

            serializer = self.get_serializer(conversation)
            return Response(
                serializer.data,
                status=status.HTTP_201_CREATED
            )

    @action(detail=True, methods=["post"], url_path="mark-read")
    def mark_read(self, request, pk=None):
        conversation = self.get_object()
        updated_count = conversation.messages.exclude(
            sender=request.user
        ).filter(is_read=False).update(is_read=True)
        return Response({"updated_count": updated_count})

class MessageViewSet(viewsets.ModelViewSet):
    serializer_class = MessageSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = MarketplacePagination

    def get_queryset(self):
        queryset = (
            Message.objects
            .filter(conversation__participants=self.request.user)
            .select_related(
                "sender",
                "conversation",
                "product",
                "reply_to",
                "reply_to__sender",
            )
            .prefetch_related("product__images")
            .order_by("created_at")
        )


        conversation_id = self.request.query_params.get("conversation")
        if conversation_id:
            queryset = queryset.filter(conversation_id=conversation_id)

        after_id = self.request.query_params.get("after")
        if after_id:
            try:
                after_id = int(after_id)
                queryset = queryset.filter(id__gt=after_id)
            except ValueError:
                return queryset.none()

        return queryset

    @action(detail=True, methods=["get"], url_path="attachment")
    def attachment(self, request, pk=None):
        message = self.get_object()
        if not message.attachment:
            return Response({"detail": "This message has no attachment."}, status=status.HTTP_404_NOT_FOUND)
        content_type = mimetypes.guess_type(message.attachment.name)[0]
        response = FileResponse(
            message.attachment.open("rb"),
            content_type=content_type or "application/octet-stream",
        )
        response["Content-Disposition"] = "inline"
        return response



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

        reply_to = serializer.validated_data.get("reply_to")
        if reply_to is not None and reply_to.conversation_id != conversation.id:
            raise ValidationError(
                {"reply_to": "You can only reply to a message in this conversation."}
            )

        product_id = self.request.data.get("product")

        product = None
        if product_id not in (None, ""):
            product = get_object_or_404(
                Product.objects.select_related("business__user"),
                id=product_id
            )

            participants = list(
                conversation.participants.all()
            )

            if len(participants) != 2:
                raise PermissionDenied(
                    "Product context requires a conversation between two users."
                )

            participant_ids = {user.id for user in participants}

            if product.business.user_id not in participant_ids:
                raise PermissionDenied(
                    "The listing owner must be a participant in this conversation."
                )

        message = serializer.save(
            sender=self.request.user,
            conversation=conversation,
            product=product
        )

        recipient = conversation.participants.exclude(
            id=self.request.user.id
        ).first()

        if recipient:
            create_notification(
                recipient=recipient,
                sender=self.request.user,
                notification_type=Notification.MESSAGE,
                message=f"{self.request.user.username} sent you a message.",
                conversation=conversation,
            )


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
            user=self.request.user,
            product__business__is_suspended=False,
        ).select_related("product")

    def perform_create(self, serializer):
        product_id = self.request.data.get("product")

        product = get_object_or_404(
            Product,
            id=product_id
        )

        if product.business.is_suspended:
            raise ValidationError("This listing is unavailable.")

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

        if business.is_suspended:
            raise ValidationError("This business profile is suspended.")

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

    def perform_destroy(self, instance):
        # A community membership depends on following the business.
        CommunityMembership.objects.filter(
            user=self.request.user,
            business=instance.business,
        ).delete()
        instance.delete()


class CommunityViewSet(viewsets.ReadOnlyModelViewSet):
    """Community listings are available to followers and the business owner."""

    serializer_class = CommunitySerializer
    permission_classes = [IsAuthenticated]
    pagination_class = MarketplacePagination

    def get_queryset(self):
        user = self.request.user
        return BusinessProfile.objects.filter(is_suspended=False).filter(
            Q(followers__user=user) | Q(user=user)
        ).select_related("user").distinct().order_by("name")

    @action(detail=True, methods=["post"])
    def join(self, request, pk=None):
        business = self.get_object()
        if business.user_id == request.user.id:
            return Response({"detail": "You own this community."}, status=status.HTTP_200_OK)
        if not BusinessFollow.objects.filter(user=request.user, business=business).exists():
            raise PermissionDenied("Follow this business before joining its community.")
        membership, created = CommunityMembership.objects.get_or_create(
            user=request.user,
            business=business,
        )
        return Response(
            {"joined": True, "created": created, "joined_at": membership.joined_at},
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

    @action(detail=True, methods=["post"])
    def leave(self, request, pk=None):
        business = self.get_object()
        if business.user_id == request.user.id:
            raise ValidationError("The business owner cannot leave their own community.")
        CommunityMembership.objects.filter(user=request.user, business=business).delete()
        return Response({"joined": False}, status=status.HTTP_200_OK)


class CommunityPostViewSet(viewsets.ModelViewSet):
    serializer_class = CommunityPostSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = MarketplacePagination
    http_method_names = ["get", "post", "delete", "head", "options"]

    def get_queryset(self):
        business_id = self.request.query_params.get("business")
        if not business_id:
            return CommunityPost.objects.none()
        user = self.request.user
        return CommunityPost.objects.filter(
            business_id=business_id,
            business__is_suspended=False,
        ).filter(
            Q(business__user=user) | Q(business__community_memberships__user=user)
        ).select_related("business", "author").distinct()

    def perform_create(self, serializer):
        business = get_object_or_404(
            BusinessProfile,
            id=self.request.data.get("business"),
            is_suspended=False,
        )
        if business.user_id != self.request.user.id:
            raise PermissionDenied("Only this business can publish community updates.")
        serializer.save(business=business, author=self.request.user)

    def perform_destroy(self, instance):
        if instance.business.user_id != self.request.user.id:
            raise PermissionDenied("Only the business can remove its community updates.")
        instance.delete()




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
            business__is_suspended=False,
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
            school=school,
            is_suspended=False,
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
            business__is_suspended=False,
            is_available=True,
            is_private=False
            ).select_related(
                "business",
                "category",
            ).prefetch_related(
                "images",
            )
        all_listings = products.order_by("-created_at")[:100]
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
            "all_listings": all_listings,
        }, context={"request": request})

        return Response(serializer.data)


class AppVisitView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        AppVisit.objects.create(user=request.user)
        return Response({"recorded": True}, status=status.HTTP_201_CREATED)


class AdminAnalyticsView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        today = timezone.localdate()
        start_date = today - timedelta(days=29)
        start_at = timezone.make_aware(
            timezone.datetime.combine(start_date, timezone.datetime.min.time())
        )

        def daily_counts(queryset, field):
            rows = (
                queryset.filter(**{f"{field}__gte": start_at})
                .annotate(day=TruncDate(field, tzinfo=timezone.get_current_timezone()))
                .values("day")
                .annotate(count=Count("id"))
                .order_by("day")
            )
            counts = {row["day"].isoformat(): row["count"] for row in rows}
            return [
                {"date": (start_date + timedelta(days=offset)).isoformat(),
                 "count": counts.get((start_date + timedelta(days=offset)).isoformat(), 0)}
                for offset in range(30)
            ]

        categories = Category.objects.annotate(
            business_count=Count("businessprofile")
        ).order_by("name")

        return Response({
            "total_users": User.objects.filter(
                is_staff=False, is_superuser=False
            ).count(),
            "total_business_profiles": BusinessProfile.objects.count(),
            "users_registered_daily": daily_counts(
                User.objects.filter(is_staff=False, is_superuser=False), "date_joined"
            ),
            "app_visits_daily": daily_counts(AppVisit.objects.all(), "visited_at"),
            "business_profiles_by_category": [
                {"category": category.name, "count": category.business_count}
                for category in categories
            ],
        })

class RecentlyViewedView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        views = (
            ProductView.objects
            .filter(
                user=request.user,
                product__business__is_suspended=False,
            )
            .select_related(
                "product",
                "product__business",
                "product__category",
            )
            .order_by("-viewed_at")
        )

        # Keep one recent entry per listing, using its latest visit.
        recent_views = []
        seen_product_ids = set()
        for view in views.iterator():
            if view.product_id in seen_product_ids:
                continue
            seen_product_ids.add(view.product_id)
            recent_views.append(view)
            if len(recent_views) == 30:
                break

        serializer = RecentlyViewedSerializer(
            recent_views,
            many=True
        )

        return Response(serializer.data)


class RecentlyViewedBusinessesView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        visits = (
            BusinessProfileVisit.objects
            .filter(user=request.user, business__is_suspended=False)
            .select_related("business", "business__category", "business__school")
            .order_by("-viewed_at")[:30]
        )
        return Response([
            {
                "id": visit.id,
                "business": BusinessProfileSerializer(
                    visit.business, context={"request": request}
                ).data,
                "viewed_at": visit.viewed_at,
            }
            for visit in visits
        ])

class ReportViewSet(viewsets.ModelViewSet):
    serializer_class = ReportSerializer
    pagination_class = None
    http_method_names = ["get", "post", "head", "options"]

    def get_queryset(self):
        queryset = Report.objects.select_related(
            "reporter",
            "product",
            "business",
            "business__user",
            "business__school",
            "product__business__user",
            "product__business__school",
        ).order_by("-created_at")
        if self.request.user.is_staff:
            return queryset
        return queryset.none()

    def get_permissions(self):
        if self.action == "create":
            return [IsAuthenticated()]
        return [IsAdminUser()]

    def perform_create(self, serializer):
        with transaction.atomic():
            report = serializer.save(reporter=self.request.user)
            admin_sender = User.objects.filter(
                is_staff=True
            ).exclude(
                id=self.request.user.id
            ).order_by("id").first()
            if admin_sender is not None:
                reported_item = (
                    f'listing “{report.product.name}”'
                    if report.product_id
                    else f'business “{report.business.name}”'
                )
                _send_inbox_message(
                    admin_sender,
                    self.request.user,
                    f"Thank you for reporting {reported_item}. The BluuBase "
                    "team has received your report and will investigate it.",
                )

    @action(detail=True, methods=["post"], url_path="review")
    def review(self, request, pk=None):
        report = self.get_object()
        if report.review_status != Report.PENDING:
            raise ValidationError({"detail": "This report has already been reviewed."})
        outcome = request.data.get("outcome")
        if outcome not in (Report.REVIEWED, Report.DISMISSED):
            raise ValidationError({
                "outcome": "Choose 'reviewed' or 'dismissed'.",
            })

        reporter_notified = False
        owner_notified = False
        with transaction.atomic():
            report.review_status = outcome
            report.reviewed_at = timezone.now()
            report.reviewed_by = request.user
            report.save(update_fields=["review_status", "reviewed_at", "reviewed_by"])

            if outcome == Report.DISMISSED:
                business = report.business
                if business is None and report.product_id:
                    business = report.product.business

                reported_item = (
                    f'listing “{report.product.name}”'
                    if report.product_id
                    else f'business “{business.name}”'
                )
                if report.reporter_id != request.user.id:
                    reporter_notified = _send_inbox_message(
                        request.user,
                        report.reporter,
                        f"Thank you for reporting {reported_item}. The BluuBase "
                        "team reviewed it and did not find a violation, so no "
                        "action was taken.",
                    )

                if business is not None and business.user_id != request.user.id:
                    owner_message = (
                        f'The BluuBase team reviewed a report concerning your '
                        f'business profile “{business.name}” and did not find '
                        "a violation. No action was taken against your "
                        "business profile or listings. The reporter’s identity "
                        "is not shared."
                    )
                    if business.user_id == report.reporter_id:
                        owner_notified = reporter_notified
                    else:
                        owner_notified = _send_inbox_message(
                            request.user,
                            business.user,
                            owner_message,
                        )

        response_data = ReportSerializer(
            report,
            context=self.get_serializer_context(),
        ).data
        response_data["reporter_notified"] = reporter_notified
        response_data["owner_notified"] = owner_notified
        return Response(response_data)

    @action(detail=True, methods=["post"], url_path="suspend-business")
    def suspend_business(self, request, pk=None):
        report = self.get_object()
        business = report.business
        if business is None and report.product_id:
            business = report.product.business
        if business is None:
            raise ValidationError("This report is not linked to a business.")

        if business.is_suspended:
            return Response({
                "detail": "This business profile is already suspended.",
                "business_id": business.id,
                "is_suspended": True,
                "message_sent": False,
            })

        owner = business.user
        message_sent = False
        reporters_notified = 0
        with transaction.atomic():
            business.is_suspended = True
            business.save(update_fields=["is_suspended"])

            Report.objects.filter(
                Q(business=business) | Q(product__business=business),
                review_status=Report.PENDING,
            ).update(
                review_status=Report.ACTION_TAKEN,
                reviewed_at=timezone.now(),
                reviewed_by=request.user,
            )

            message_sent = _send_inbox_message(
                request.user,
                owner,
                f'Your business profile “{business.name}” has been '
                "suspended after an administrator review. This action "
                "applies to your business profile only; your user account "
                "remains active. Please contact the BluuBase team if you "
                "need help.",
            )

            reporter_ids = Report.objects.filter(
                Q(business=business) | Q(product__business=business)
            ).values_list("reporter_id", flat=True).distinct()
            reporters = User.objects.filter(id__in=reporter_ids).exclude(
                id=request.user.id
            )
            for reporter in reporters:
                if _send_inbox_message(
                    request.user,
                    reporter,
                    f"Thank you for reporting {business.name}. We investigated "
                    "the report and suspended the business profile.",
                ):
                    reporters_notified += 1

        return Response({
            "detail": "Business profile suspended.",
            "business_id": business.id,
            "is_suspended": True,
            "message_sent": message_sent,
            "reporters_notified": reporters_notified,
        })

    @action(detail=True, methods=["post"], url_path="unsuspend-business")
    def unsuspend_business(self, request, pk=None):
        report = self.get_object()
        business = report.business
        if business is None and report.product_id:
            business = report.product.business
        if business is None:
            raise ValidationError("This report is not linked to a business.")

        if not business.is_suspended:
            return Response({
                "detail": "This business profile is not suspended.",
                "business_id": business.id,
                "is_suspended": False,
                "message_sent": False,
            })

        with transaction.atomic():
            business.is_suspended = False
            business.save(update_fields=["is_suspended"])
            message_sent = _send_inbox_message(
                request.user,
                business.user,
                f'Your business profile “{business.name}” has been '
                "unsuspended after an administrator review and is available "
                "to customers again. Your user account was not suspended.",
            )

        return Response({
            "detail": "Business profile unsuspended.",
            "business_id": business.id,
            "is_suspended": False,
            "message_sent": message_sent,
        })

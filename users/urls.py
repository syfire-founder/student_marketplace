from django.urls import path
from rest_framework.authtoken.views import obtain_auth_token
from rest_framework.routers import DefaultRouter
from django.conf import settings
from django.conf.urls.static import static
from django.urls import include



from .views import (
    CategoryListView,
    RegisterView,
    ProductViewSet,
    ListingImageViewSet,
    BusinessProfileViewSet,
    CategoryListCreateView,
    CategoryRetrieveUpdateDestroyView,
    SchoolViewSet,
    UserProfileView,
    ReviewViewSet,
    BusinessDashboardView,
    ConversationViewSet,
    MessageViewSet,
    ProductFavoriteViewSet,
    BusinessFollowViewSet,
    NotificationViewSet,
    UnreadNotificationCountView,
    SearchView,
    HomeFeedView,
    RecentlyViewedView,
    ReportViewSet,
)
#BusinessProfileListCreateView
#BusinessProfileDetailView,

router = DefaultRouter()
router.register(r'products', ProductViewSet, basename='product')
router.register(r'listing-images', ListingImageViewSet, basename='listing-images')
router.register(r'businessprofiles', BusinessProfileViewSet, basename='businessprofile')
router.register(r'schools', SchoolViewSet, basename='school')
router.register(
    r"reviews",
    ReviewViewSet,
    basename="review"
)
router.register(
    r"conversations",
    ConversationViewSet,
    basename="conversation"
)

router.register(
    r"messages",
    MessageViewSet,
    basename="message"
)

router.register(
    r"product-favorites",
    ProductFavoriteViewSet,
    basename="product-favorite"
)

router.register(
    r"business-follows",
    BusinessFollowViewSet,
    basename="business-follow"
)
router.register(
    r"notifications",
    NotificationViewSet,
    basename="notification"
)
router.register(
    r"reports",
    ReportViewSet,
    basename="report"
)
urlpatterns = [
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/login/', obtain_auth_token, name='login'),

    path(
    "notifications/unread-count/",
    UnreadNotificationCountView.as_view(),
),

    path('categories/', CategoryListCreateView.as_view(), name='category-list-create'),
    path('', include(router.urls)),

    path(
    "categories/<int:pk>/",
    CategoryRetrieveUpdateDestroyView.as_view(),
    name="category-detail",
),
    
    path(
    "profile/",
    UserProfileView.as_view(),
    name="user-profile",
),

    path(
    "business-dashboard/",
    BusinessDashboardView.as_view(),
),
    
    path(
    "search/",
    SearchView.as_view(),
    name="search",
),
    
    path(
    "feed/",
    HomeFeedView.as_view(),
),

    path(
    "recently-viewed/",
    RecentlyViewedView.as_view(),
),
]

    #path('businesses/', BusinessProfileListCreateView.as_view(), name='business-list-create'),
    #path('businesses/<int:pk>/', BusinessProfileDetailView.as_view(), name='business-detail'),

if settings.DEBUG:urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)


urlpatterns += router.urls




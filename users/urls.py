from django.urls import path
from rest_framework.authtoken.views import obtain_auth_token
from rest_framework.routers import DefaultRouter

from .views import (
    CategoryListView,
    BusinessProfileListCreateView,
    BusinessProfileDetailView,
    RegisterView,
    ProductListCreateView,
    ProductDetailView,
    ProductViewSet
)

urlpatterns = [
    # Auth
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/login/', obtain_auth_token, name='login'),

    # Categories
    path('categories/', CategoryListView.as_view(), name='category-list'),

    # Businesses
    path('businesses/', BusinessProfileListCreateView.as_view(), name='business-list-create'),
    path('businesses/<int:pk>/', BusinessProfileDetailView.as_view(), name='business-detail'),

    #products
    path("products/", ProductListCreateView.as_view(), name="product-list-create"),
    path("products/<int:pk>/", ProductDetailView.as_view(), name="product-detail"),

]




router = DefaultRouter()
router.register(r'products', ProductViewSet, basename='product')

urlpatterns = router.urls

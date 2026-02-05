from django.urls import path
from .views import (
    CategoryListView,
    BusinessProfileListCreateView,
    BusinessProfileDetailView,
)

urlpatterns = [
    path("categories/", CategoryListView.as_view(), name="category-list"),

    path("businesses/", BusinessProfileListCreateView.as_view(), name="business-list-create"),
    path("businesses/<int:pk>/", BusinessProfileDetailView.as_view(), name="business-detail"),
]

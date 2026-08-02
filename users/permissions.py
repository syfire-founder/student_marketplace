from rest_framework.permissions import BasePermission, SAFE_METHODS
from rest_framework import permissions





class IsOwnerOrReadOnly(BasePermission):
    """
    Anyone can view products.
    Only the owner of the business can update or delete.
    """

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True

        return obj.business.user == request.user


class IsBusinessOwnerOrReadOnly(BasePermission):
    """
    Anyone can read.
    Only the owner of the business can edit/delete.
    """

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True

        return obj.business.user == request.user


class IsBusinessOwner(BasePermission):
    """
    Anyone can view a business profile.
    Only the owner can modify it.
    """

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True

        return obj.user == request.user


class IsReviewOwner(BasePermission):
    """
    Only the owner of a review can edit or delete it.
    """

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True

        return obj.user == request.user
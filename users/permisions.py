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
    only the owner of the business can edit or delete its products.
    anyone can read.
    """
    def has_object_permission(self, request, view, obj):
        #safe methods like GET, HEAD, OPTIONS are always allowed for any authenticated user
        if request.method in ['GET', 'HEAD', 'OPTIONS']:
            return True
        #Only the owner of the business can edit/delete
        return obj.business.user == request.user
    
    

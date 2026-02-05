from rest_framework.permissions import BasePermission, SAFE_METHODS

class IsOwnerOrReadOnly(BasePermission):
    """
    Custom Permission:
    - Owners can edit/delete.
    - others can only read.
    """
    def has_object_permission(self, request, view, obj):
        #read only permissions for GET,HEAD,OPTIONS
        if request.method in SAFE_METHODS:
            return True
        # only owner can edit/delete
        return obj.user == request.user
    

    
    

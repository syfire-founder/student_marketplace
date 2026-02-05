from django.db import models
from django.conf import settings
from django.contrib.auth.models import User



class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)

    class Meta:
        verbose_name_plural = "Categories"
        
    def __str__(self):
        return self.name


class BusinessProfile(models.Model):
    user = models.ForeignKey(
        User, 
        on_delete=models.CASCADE,
        related_name="businesses",
        null=True,
        blank=True,
        )
    business_name = models.CharField(max_length=255)
    business_category = models.ForeignKey(Category,
    on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return self.business_name
    

   
    


    
    
# Create your models here.

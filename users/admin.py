from django.contrib import admin
from .models import Category, BusinessProfile


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ("id", "name",)
    


@admin.register(BusinessProfile)
class BusinessProfileAdmin(admin.ModelAdmin):
    list_display = ("id", "business_name", "business_category",'user', 'created_at')
    list_filter = ("business_category",)
    search_fields = ("business_name",)
    

# Register your models here.

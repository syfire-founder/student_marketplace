from django.contrib import admin
from .models import BusinessProfile, Category, Product


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ("id", "name")


@admin.register(BusinessProfile)
class BusinessProfileAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "category")
    list_filter = ("category",)


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "business", "price", "created_at")
    list_filter = ("business",)

    

# Register your models here.

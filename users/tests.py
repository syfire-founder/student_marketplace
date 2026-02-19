from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.test import APITestCase

from .models import BusinessProfile, Product, Category


class ProductAPITest(APITestCase):

    def setUp(self):
        # users
        self.user = User.objects.create_user(
            username="owner",
            password="password123"
        )

        self.other_user = User.objects.create_user(
            username="outsider",
            password="password123"
        )

        # category
        self.category = Category.objects.create(name="Electronics")

        # business
        self.business = BusinessProfile.objects.create(
            user=self.user,
            business_name="Owner Business",
            category=self.category
        )

        # product
        self.product = Product.objects.create(
            name="Laptop",
            price=1000,
            business=self.business
        )

        self.products_url = "/api/products/"

    # -------------------------
    # LIST PRODUCTS
    # -------------------------
    def test_list_products(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.get("/api/products/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 1)

    # -------------------------
    # CREATE PRODUCT (OWNER)
    # -------------------------
    def test_create_product(self):
        self.client.force_authenticate(user=self.user)

        data = {
            "name": "Phone",
            "price": 500
        }

        response = self.client.post(self.products_url, data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Product.objects.count(), 2)

    # -------------------------
    # CREATE PRODUCT (NO BUSINESS)
    # -------------------------
    def test_user_without_business_cannot_create(self):
        self.client.force_authenticate(user=self.other_user)

        data = {
            "name": "Tablet",
            "price": 300
        }

        response = self.client.post(self.products_url, data)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


    def test_other_user_cannot_update_product(self):
        self.client.force_authenticate(user=self.other_user)

        url = f"/api/products/{self.product.id}/"

        response = self.client.patch(url, {"name": "Hacked"})
        self.assertEqual(response.status_code, 403)




    def test_other_user_cannot_delete_product(self):
        self.client.force_authenticate(user=self.other_user)

        url = f"/api/products/{self.product.id}/"

        response = self.client.delete(url)
        self.assertEqual(response.status_code, 403)


    def test_other_user_can_view_product(self):
        self.client.force_authenticate(user=self.other_user)

        url = f"/api/products/{self.product.id}/"

        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)


    def test_cannot_view_private_product_of_other_user(self):
        other_user = User.objects.create_user(
            username="other",
         password="password123"
    )

        other_business = BusinessProfile.objects.create(
            user=other_user,
        name="Other Biz"
    )

        private_product = Product.objects.create(
            name="Secret Product",
        business=other_business,
        is_public=False
    )

        self.client.force_authenticate(user=self.user)

        response = self.client.get(f"/api/products/{private_product.id}/")

        self.assertEqual(response.status_code, 404)



    def test_anonymous_cannot_see_private_product(self):
        private_product = Product.objects.create(
            name="Private",
            business=self.business,
            is_public=False
    )

        response = self.client.get(f"/api/products/{private_product.id}/")

        self.assertEqual(response.status_code, 404)
  

    def test_owner_can_see_own_private_product(self):
        private_product = Product.objects.create(
            name="Mine",
            business=self.business,
            is_public=False
    )

        self.client.force_authenticate(user=self.user)

        response = self.client.get(f"/api/products/{private_product.id}/")

        self.assertEqual(response.status_code, 200)


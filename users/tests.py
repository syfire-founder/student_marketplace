from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.test import APITestCase

from .models import BusinessProfile, Product, Category, School
from django.db.models import ProtectedError
from .models import UserProfile

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

        #school

        self.school = School.objects.create(name="Test University")

        UserProfile.objects.create(user=self.user, school=self.school)
        UserProfile.objects.create(user=self.other_user, school=self.school)


        # business
        self.business = BusinessProfile.objects.create(
            user=self.user,
            name="Owner Business",
            category=self.category,
            school = self.school
        )

        # product
        self.product = Product.objects.create(
            name="Test Product",
            price=1000.00,
            is_private=False,
            business=self.business
        )

        self.products_url = "/api/products/"

        self.private_product = Product.objects.create(
            name="Private Product",
            business=self.business,
            price=100,
            is_private=True
            )

    # -------------------------
    # LIST PRODUCTS
    # -------------------------
    def test_list_products(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.get("/api/products/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 2)

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
        self.assertEqual(Product.objects.count(), 3)

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
            name="Other Biz",
            category=self.category,
            school=self.school
    )

        private_product = Product.objects.create(
            name="Secret Product",
            price=50000,
        business=other_business,
        is_private=True
    )

        self.client.force_authenticate(user=self.user)

        response = self.client.get(f"/api/products/{private_product.id}/")

        self.assertEqual(response.status_code, 404)



    def test_anonymous_cannot_see_private_product(self):
        private_product = Product.objects.create(
            name="Private",
            price=4000,
            business=self.business,
            is_private=True
    )

        response = self.client.get(f"/api/products/{private_product.id}/")

        self.assertEqual(response.status_code, 404)
  

    def test_owner_can_see_own_private_product(self):
        private_product = Product.objects.create(
            name="Mine",
            price=30000,
            business=self.business,
            is_private=True
    )

        self.client.force_authenticate(user=self.user)

        response = self.client.get(f"/api/products/{private_product.id}/")

        self.assertEqual(response.status_code, 200)

    def test_category_cannot_be_deleted_if_business_exists(self):
        with self.assertRaises(ProtectedError):
            self.category.delete()



    def test_private_product_not_in_list_for_other_user(self):
        other_user = User.objects.create_user(
            username="other",
            password="password123"
        )
        self.client.force_authenticate(user=other_user)
        response = self.client.get("/api/products/")
        self.assertEqual(response.status_code, 200)
        self.assertNotContains(response, self.private_product.name)

        """ 
        self.assertNotIn(
    self.private_product.id,
    [p["id"] for p in response.data["results"]]
)
"""
       


        """
        self.client.login(username="other", password="password123")

        response = self.client.get("/products/")
        self.assertNotContains(response, self.private_product.name)
        """

    
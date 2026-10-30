import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/token_storage.dart';

class AuthRepository {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  AuthRepository({required this.apiClient, required this.tokenStorage});

  Future<String> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/auth/login/',
        data: {'username': username, 'password': password},
      );

      final token = response.data['token'];

      if (token == null || token.toString().isEmpty) {
        throw Exception('Login succeeded but no token was returned.');
      }

      await tokenStorage.saveToken(token.toString());

      return token.toString();
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required int school,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/auth/register/',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'school': school,
        },
      );

      final token = response.data['token']?.toString();
      if (token != null && token.isNotEmpty) {
        await tokenStorage.saveToken(
          token,
          isAdmin: response.data['is_admin'] == true,
        );
        return true;
      }
      return false;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<String> verifyRegistration({
    required String email,
    required String code,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/auth/verify-registration/',
        data: {'email': email, 'code': code},
      );
      final token = response.data['token']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('Registration could not be completed.');
      }
      await tokenStorage.saveToken(token);
      return token;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> logout() async {
    await tokenStorage.deleteToken();
  }

  Future<String?> getStoredToken() async {
    return tokenStorage.getToken();
  }

  String _extractError(DioException error) {
    final data = error.response?.data;

    if (data is Map<String, dynamic>) {
      if (data['detail'] != null) {
        return data['detail'].toString();
      }

      if (data.isNotEmpty) {
        return data.values.first.toString();
      }
    }

    return 'Something went wrong. Please try again.';
  }
}

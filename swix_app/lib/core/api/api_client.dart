import 'package:dio/dio.dart';

class ApiClient {
  // Defaults to the Android emulator's local Django server. Set API_BASE_URL
  // with --dart-define for a real-device build, e.g. https://api.example.com/api.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  final Dio dio;

  ApiClient()
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
}

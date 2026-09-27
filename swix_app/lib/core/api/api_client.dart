import 'package:dio/dio.dart';

class ApiClient {
  // Android emulator address for the backend running on your computer.
  static const String baseUrl = 'http://10.0.2.2:8000/api';

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

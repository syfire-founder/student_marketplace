import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const String _tokenKey = 'auth_token';

  final FlutterSecureStorage _storage;

  const TokenStorage({this._storage = const FlutterSecureStorage()});

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);

    final verify = await _storage.read(key: _tokenKey);

    if (verify == null || verify.isEmpty) {
      throw Exception('Token was not persisted to secure storage.');
    }
  }

  Future<String?> getToken() async {
    final token = await _storage.read(key: _tokenKey);

    return token;
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }
}

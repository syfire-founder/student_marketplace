import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const String _tokenKey = 'auth_token';
  static const String _adminKey = 'auth_is_admin';

  final FlutterSecureStorage _storage;

  const TokenStorage({this._storage = const FlutterSecureStorage()});

  Future<void> saveToken(String token, {bool isAdmin = false}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _adminKey, value: isAdmin ? 'true' : 'false');

    final verify = await _storage.read(key: _tokenKey);

    if (verify == null || verify.isEmpty) {
      throw Exception('Token was not persisted to secure storage.');
    }
  }

  Future<String?> getToken() async {
    final token = await _storage.read(key: _tokenKey);

    return token;
  }

  Future<bool> getIsAdmin() async {
    return await _storage.read(key: _adminKey) == 'true';
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _adminKey);
  }
}

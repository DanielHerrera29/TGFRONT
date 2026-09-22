import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RememberedLogin {
  final FlutterSecureStorage storage;
  static const key = 'teg_remember_login_v1';
  RememberedLogin({FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();
  Future<Map<String, dynamic>?> read() async {
    final value = await storage.read(key: key);
    return value == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  Future<void> save(Map<String, dynamic> value) =>
      storage.write(key: key, value: jsonEncode(value));
  Future<void> clear() => storage.delete(key: key);
}

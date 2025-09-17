import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// 데이터 저장
  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// 데이터 조회
  static Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// 데이터 삭제
  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// 모든 데이터 삭제
  static Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  /// 키 존재 여부 확인
  static Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }

  /// 모든 키 조회
  static Future<Map<String, String>> readAll() async {
    return await _storage.readAll();
  }
}

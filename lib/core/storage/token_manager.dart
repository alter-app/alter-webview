import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../../config/app_config.dart';

class TokenManager {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// JWT 토큰 저장 (서버에서 제공받은 토큰)
  static Future<void> saveToken(String token) async {
    await _secureStorage.write(key: AppConfig.tokenKey, value: token);
  }

  /// JWT 토큰 조회
  static Future<String?> getToken() async {
    return await _secureStorage.read(key: AppConfig.tokenKey);
  }

  /// Refresh 토큰 저장 (서버에서 제공받은 토큰)
  static Future<void> saveRefreshToken(String refreshToken) async {
    await _secureStorage.write(key: AppConfig.refreshTokenKey, value: refreshToken);
  }

  /// Refresh 토큰 조회
  static Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: AppConfig.refreshTokenKey);
  }

  /// 토큰 유효성 검증 (서버에서 제공받은 토큰의 만료시간 확인)
  static bool isTokenValid(String token) {
    try {
      final jwt = JWT.decode(token);
      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      final exp = jwt.payload['exp'] as int?;
      
      if (exp == null) return false;
      
      // 토큰이 아직 유효한지 확인 (현재 시간이 만료 시간보다 이전인지)
      return now < exp;
    } catch (e) {
      return false;
    }
  }

  /// 토큰 만료 시간 조회
  static DateTime? getTokenExpiration(String token) {
    try {
      final jwt = JWT.decode(token);
      final exp = jwt.payload['exp'] as int?;
      return exp != null ? DateTime.fromMillisecondsSinceEpoch(exp * 1000) : null;
    } catch (e) {
      return null;
    }
  }

  /// 토큰에서 사용자 정보 추출
  static Map<String, dynamic>? getUserInfo(String token) {
    try {
      final jwt = JWT.decode(token);
      return jwt.payload;
    } catch (e) {
      return null;
    }
  }

  /// 모든 토큰 삭제
  static Future<void> clearTokens() async {
    await _secureStorage.delete(key: AppConfig.tokenKey);
    await _secureStorage.delete(key: AppConfig.refreshTokenKey);
    await _secureStorage.delete(key: AppConfig.userDataKey);
  }

  /// 토큰 존재 여부 확인
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// 유효한 토큰 존재 여부 확인
  static Future<bool> hasValidToken() async {
    final token = await getToken();
    return token != null && isTokenValid(token);
  }
}

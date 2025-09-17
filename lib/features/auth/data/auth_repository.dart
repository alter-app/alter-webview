import 'package:dio/dio.dart';
import '../../../core/storage/token_manager.dart';
import '../../../config/app_config.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  /// 로그인
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '${AppConfig.apiBaseUrl}auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final token = data['access_token'];
        final refreshToken = data['refresh_token'];

        if (token != null) {
          await TokenManager.saveToken(token);
        }
        if (refreshToken != null) {
          await TokenManager.saveRefreshToken(refreshToken);
        }

        return data;
      } else {
        throw Exception('Login failed: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  /// 토큰 갱신 (서버에서 새로운 토큰을 받아서 저장)
  Future<String> refreshToken() async {
    try {
      final refreshToken = await TokenManager.getRefreshToken();
      if (refreshToken == null) {
        throw Exception('No refresh token available');
      }

      final response = await _dio.post(
        '${AppConfig.apiBaseUrl}auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final newToken = data['access_token'];
        final newRefreshToken = data['refresh_token'];

        if (newToken != null) {
          await TokenManager.saveToken(newToken);
        }
        if (newRefreshToken != null) {
          await TokenManager.saveRefreshToken(newRefreshToken);
        }
        
        return newToken ?? '';
      }
      throw Exception('Token refresh failed');
    } catch (e) {
      throw Exception('Token refresh error: $e');
    }
  }

  /// 로그아웃
  Future<void> logout() async {
    try {
      final token = await TokenManager.getToken();
      if (token != null) {
        await _dio.post(
          '${AppConfig.apiBaseUrl}auth/logout',
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
          ),
        );
      }
    } catch (e) {
      // 로그아웃은 실패해도 토큰을 삭제해야 함
    } finally {
      await TokenManager.clearTokens();
    }
  }

  /// 사용자 정보 조회
  Future<Map<String, dynamic>> getUserInfo() async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) {
        throw Exception('No token available');
      }

      final response = await _dio.get(
        '${AppConfig.apiBaseUrl}user/profile',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get user info: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Get user info error: $e');
    }
  }
}

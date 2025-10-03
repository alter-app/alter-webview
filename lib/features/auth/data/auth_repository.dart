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
          await TokenManager.saveAccessToken(token);
        }
        if (refreshToken != null) {
          await TokenManager.saveRefreshToken(refreshToken);
        }

        return data;
      } else {
        throw Exception('로그인에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('로그인에 실패했습니다. 다시 시도해주세요.');
    }
  }

  // 토큰 갱신은 웹에서 처리하므로 제거

  /// 로그아웃
  Future<void> logout() async {
    try {
      final token = await TokenManager.getAccessToken();
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
      final token = await TokenManager.getAccessToken();
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
        throw Exception('사용자 정보를 가져올 수 없습니다.');
      }
    } catch (e) {
      throw Exception('사용자 정보 조회에 실패했습니다.');
    }
  }
}

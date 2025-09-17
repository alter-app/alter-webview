import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../../core/storage/token_manager.dart';
import '../../../config/app_config.dart';
import 'package:dio/dio.dart';

// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = Dio();
  dio.options.baseUrl = AppConfig.apiBaseUrl;
  dio.options.connectTimeout = const Duration(seconds: 30);
  dio.options.receiveTimeout = const Duration(seconds: 30);
  
  // Request Interceptor
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenManager.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // 토큰 만료 시 갱신 시도
          try {
            final authRepo = AuthRepository(dio);
            await authRepo.refreshToken();
            
            // 원래 요청 재시도
            final token = await TokenManager.getToken();
            if (token != null) {
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              final response = await dio.fetch(error.requestOptions);
              handler.resolve(response);
              return;
            }
          } catch (e) {
            // 토큰 갱신 실패 시 로그아웃
            await TokenManager.clearTokens();
          }
        }
        handler.next(error);
      },
    ),
  );
  
  return AuthRepository(dio);
});

// Auth State
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? token;
  final String? error;
  final Map<String, dynamic>? userInfo;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.token,
    this.error,
    this.userInfo,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? token,
    String? error,
    Map<String, dynamic>? userInfo,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      error: error,
      userInfo: userInfo ?? this.userInfo,
    );
  }
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final token = await TokenManager.getToken();
    if (token != null && TokenManager.isTokenValid(token)) {
      state = state.copyWith(
        isAuthenticated: true,
        token: token,
      );
      await getUserInfo();
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _authRepository.login(email, password);
      final token = result['access_token'];
      
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: token,
      );
      
      await getUserInfo();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    
    try {
      await _authRepository.logout();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> getUserInfo() async {
    try {
      final userInfo = await _authRepository.getUserInfo();
      state = state.copyWith(userInfo: userInfo);
    } catch (e) {
      // 사용자 정보 조회 실패는 에러로 처리하지 않음
    }
  }

  Future<void> refreshToken() async {
    try {
      final newToken = await _authRepository.refreshToken();
      state = state.copyWith(token: newToken);
    } catch (e) {
      await logout();
    }
  }
}

// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});

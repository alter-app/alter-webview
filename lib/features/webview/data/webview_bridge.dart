import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/token_manager.dart';
import '../../location/presentation/location_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import '../../auth/presentation/auth_provider.dart';
import '../../location/data/location_repository.dart';

class WebViewBridge {
  final WebViewController _controller;
  final WidgetRef _ref;

  WebViewBridge(this._controller, this._ref);

  /// WebView에 토큰 주입
  Future<void> injectToken() async {
    final token = await TokenManager.getToken();
    if (token != null) {
      await _controller.runJavaScript('''
        localStorage.setItem('jwt_token', '$token');
        window.dispatchEvent(new CustomEvent('tokenInjected', { detail: { token: '$token' } }));
      ''');
    }
  }

  /// WebView에 네이티브 데이터 주입
  Future<void> injectNativeData() async {
    final deviceInfo = await _getDeviceInfo();
    final appInfo = await _getAppInfo();
    final networkInfo = await _getNetworkInfo();
    
    final nativeData = {
      'device': deviceInfo,
      'app': appInfo,
      'network': networkInfo,
      'platform': Platform.operatingSystem,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    await _controller.runJavaScript('''
      window.nativeData = ${jsonEncode(nativeData)};
      window.dispatchEvent(new CustomEvent('nativeDataInjected', { detail: ${jsonEncode(nativeData)} }));
    ''');
  }

  /// JavaScript 채널 설정
  void setupJavaScriptChannels() {
    // 위치 정보 요청 채널
    _controller.addJavaScriptChannel(
      'LocationChannel',
      onMessageReceived: (JavaScriptMessage message) async {
        await _handleLocationRequest(message.message);
      },
    );

    // 토큰 관리 채널
    _controller.addJavaScriptChannel(
      'TokenChannel',
      onMessageReceived: (JavaScriptMessage message) async {
        await _handleTokenRequest(message.message);
      },
    );

    // 네이티브 기능 요청 채널
    _controller.addJavaScriptChannel(
      'NativeChannel',
      onMessageReceived: (JavaScriptMessage message) async {
        await _handleNativeRequest(message.message);
      },
    );
  }

  /// 위치 정보 요청 처리
  Future<void> _handleLocationRequest(String message) async {
    try {
      final data = jsonDecode(message);
      final action = data['action'] as String;

      switch (action) {
        case 'getCurrentLocation':
          await _getCurrentLocationForWeb();
          break;
        case 'startTracking':
          await _startLocationTracking();
          break;
        case 'stopTracking':
          await _stopLocationTracking();
          break;
      }
    } catch (e) {
      await _sendErrorToWeb('location', e.toString());
    }
  }

  /// 토큰 요청 처리
  Future<void> _handleTokenRequest(String message) async {
    try {
      final data = jsonDecode(message);
      final action = data['action'] as String;

      switch (action) {
        case 'getToken':
          await _sendTokenToWeb();
          break;
        case 'refreshToken':
          await _refreshTokenForWeb();
          break;
        case 'clearToken':
          await _clearTokenForWeb();
          break;
      }
    } catch (e) {
      await _sendErrorToWeb('token', e.toString());
    }
  }

  /// 네이티브 기능 요청 처리
  Future<void> _handleNativeRequest(String message) async {
    try {
      final data = jsonDecode(message);
      final action = data['action'] as String;

      switch (action) {
        case 'getDeviceInfo':
          await _sendDeviceInfoToWeb();
          break;
        case 'getAppInfo':
          await _sendAppInfoToWeb();
          break;
        case 'getNetworkInfo':
          await _sendNetworkInfoToWeb();
          break;
      }
    } catch (e) {
      await _sendErrorToWeb('native', e.toString());
    }
  }

  /// 현재 위치를 WebView로 전송
  Future<void> _getCurrentLocationForWeb() async {
    try {
      final locationNotifier = _ref.read(locationProvider.notifier);
      await locationNotifier.getCurrentLocation();
      
      final state = _ref.read(locationProvider);
      if (state.currentPosition != null) {
        final locationData = {
          'latitude': state.currentPosition!.latitude,
          'longitude': state.currentPosition!.longitude,
          'accuracy': state.currentPosition!.accuracy,
          'timestamp': state.currentPosition!.timestamp.millisecondsSinceEpoch,
        };

        await _controller.runJavaScript('''
          window.dispatchEvent(new CustomEvent('locationReceived', { 
            detail: ${jsonEncode(locationData)} 
          }));
        ''');
      } else if (state.error != null) {
        await _sendErrorToWeb('location', state.error!);
      }
    } catch (e) {
      await _sendErrorToWeb('location', e.toString());
    }
  }

  /// 위치 추적 시작
  Future<void> _startLocationTracking() async {
    try {
      final locationNotifier = _ref.read(locationProvider.notifier);
      locationNotifier.startTracking();
      
      // 위치 업데이트 스트림 구독
      LocationRepository().getPositionStream().listen(
        (position) async {
          final locationData = {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'timestamp': position.timestamp.millisecondsSinceEpoch,
          };

          await _controller.runJavaScript('''
            window.dispatchEvent(new CustomEvent('locationUpdated', { 
              detail: ${jsonEncode(locationData)} 
            }));
          ''');
        },
        onError: (error) async {
          await _sendErrorToWeb('location', error.toString());
        },
      );
    } catch (e) {
      await _sendErrorToWeb('location', e.toString());
    }
  }

  /// 위치 추적 중지
  Future<void> _stopLocationTracking() async {
    try {
      final locationNotifier = _ref.read(locationProvider.notifier);
      locationNotifier.stopTracking();
      
      await _controller.runJavaScript('''
        window.dispatchEvent(new CustomEvent('locationTrackingStopped'));
      ''');
    } catch (e) {
      await _sendErrorToWeb('location', e.toString());
    }
  }

  /// 토큰을 WebView로 전송
  Future<void> _sendTokenToWeb() async {
    final token = await TokenManager.getToken();
    await _controller.runJavaScript('''
      window.dispatchEvent(new CustomEvent('tokenReceived', { 
        detail: { token: ${token != null ? '"$token"' : 'null'} } 
      }));
    ''');
  }

  /// 토큰 갱신
  Future<void> _refreshTokenForWeb() async {
    try {
      final authNotifier = _ref.read(authProvider.notifier);
      await authNotifier.refreshToken();
      
      final newToken = await TokenManager.getToken();
      await _controller.runJavaScript('''
        localStorage.setItem('jwt_token', '$newToken');
        window.dispatchEvent(new CustomEvent('tokenRefreshed', { 
          detail: { token: '$newToken' } 
        }));
      ''');
    } catch (e) {
      await _sendErrorToWeb('token', e.toString());
    }
  }

  /// 토큰 삭제
  Future<void> _clearTokenForWeb() async {
    await TokenManager.clearTokens();
    await _controller.runJavaScript('''
      localStorage.removeItem('jwt_token');
      window.dispatchEvent(new CustomEvent('tokenCleared'));
    ''');
  }

  /// 디바이스 정보 전송
  Future<void> _sendDeviceInfoToWeb() async {
    final deviceInfo = await _getDeviceInfo();
    await _controller.runJavaScript('''
      window.dispatchEvent(new CustomEvent('deviceInfoReceived', { 
        detail: ${jsonEncode(deviceInfo)} 
      }));
    ''');
  }

  /// 앱 정보 전송
  Future<void> _sendAppInfoToWeb() async {
    final appInfo = await _getAppInfo();
    await _controller.runJavaScript('''
      window.dispatchEvent(new CustomEvent('appInfoReceived', { 
        detail: ${jsonEncode(appInfo)} 
      }));
    ''');
  }

  /// 네트워크 정보 전송
  Future<void> _sendNetworkInfoToWeb() async {
    final networkInfo = await _getNetworkInfo();
    await _controller.runJavaScript('''
      window.dispatchEvent(new CustomEvent('networkInfoReceived', { 
        detail: ${jsonEncode(networkInfo)} 
      }));
    ''');
  }

  /// 에러를 WebView로 전송
  Future<void> _sendErrorToWeb(String type, String error) async {
    await _controller.runJavaScript('''
      window.dispatchEvent(new CustomEvent('nativeError', { 
        detail: { type: '$type', error: '$error' } 
      }));
    ''');
  }

  /// 디바이스 정보 조회
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return {
        'platform': 'android',
        'model': androidInfo.model,
        'version': androidInfo.version.release,
        'sdkInt': androidInfo.version.sdkInt,
        'manufacturer': androidInfo.manufacturer,
        'isPhysicalDevice': androidInfo.isPhysicalDevice,
      };
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return {
        'platform': 'ios',
        'model': iosInfo.model,
        'version': iosInfo.systemVersion,
        'name': iosInfo.name,
        'isPhysicalDevice': iosInfo.isPhysicalDevice,
      };
    }
    
    return {'platform': 'unknown'};
  }

  /// 앱 정보 조회
  Future<Map<String, dynamic>> _getAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return {
      'appName': packageInfo.appName,
      'packageName': packageInfo.packageName,
      'version': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
    };
  }

  /// 네트워크 정보 조회
  Future<Map<String, dynamic>> _getNetworkInfo() async {
    final connectivity = await Connectivity().checkConnectivity();
    return {
      'status': connectivity.name,
      'isConnected': connectivity != ConnectivityResult.none,
    };
  }
}

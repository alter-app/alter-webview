import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../../core/storage/token_manager.dart';
import '../../../core/logging/webview_logger.dart';
import '../../location/presentation/location_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import '../../location/data/location_repository.dart';

class WebViewBridge {
  final WebViewController _controller;
  final WidgetRef _ref;
  final BuildContext _context;

  WebViewBridge(this._controller, this._ref, this._context);

  /// WebView에 토큰 주입
  Future<void> injectToken() async {
    try {
      final token = await TokenManager.getAccessToken();
      if (token != null && TokenManager.isTokenValid(token)) {
        // XSS 방지를 위한 안전한 토큰 주입
        await _controller.runJavaScript('''
          (function() {
            try {
              const token = ${jsonEncode(token)};
              localStorage.setItem('jwt_token', token);
              window.dispatchEvent(new CustomEvent('tokenInjected', { 
                detail: { token: token } 
              }));
            } catch (e) {
              console.error('Token injection failed:', e);
            }
          })();
        ''');
      }
    } catch (e) {
      // 토큰 주입 실패 시 에러 로그 출력
      WebViewLogger.error('토큰 주입 실패', source: 'TokenInjection', error: e);
    }
  }

  /// WebView에 네이티브 데이터 주입
  Future<void> injectNativeData() async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final appInfo = await _getAppInfo();
      final networkInfo = await _getNetworkInfo();
      final screenInfo = await _getScreenInfo();
      
      final nativeData = {
        'device': deviceInfo,
        'app': appInfo,
        'network': networkInfo,
        'screen': screenInfo,
        'platform': Platform.operatingSystem,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _controller.runJavaScript('''
        window.nativeData = ${jsonEncode(nativeData)};
        window.dispatchEvent(new CustomEvent('nativeDataInjected', { detail: ${jsonEncode(nativeData)} }));
      ''');
      
      // 로깅 브릿지 설정 (지연 실행)
      Future.delayed(const Duration(milliseconds: 100), () async {
        await _setupConsoleLogging();
      });
      
      // 다이얼로그 오버라이드 설정 (지연 실행)
      Future.delayed(const Duration(milliseconds: 200), () async {
        await _setupDialogOverride();
      });
    } catch (e) {
      // 네이티브 데이터 주입 실패 시 에러 로그 출력
      WebViewLogger.error('네이티브 데이터 주입 실패', source: 'NativeDataInjection', error: e);
    }
  }

  /// 로깅 브릿지 설정
  Future<void> _setupConsoleLogging() async {
    try {
      // 디버깅을 위한 로그
      WebViewLogger.debug('로깅 브릿지 설정 시작', source: 'ConsoleLoggingSetup');
      
      await _controller.runJavaScript('''
        (function() {
          console.log('[WebView Bridge] 로깅 브릿지 설정 중...');
          
          // 원본 콘솔 메서드들 저장
          const originalConsole = {
            log: console.log,
            error: console.error,
            warn: console.warn,
            info: console.info,
            debug: console.debug
          };
          
          // 콘솔 메시지를 네이티브로 전송하는 함수
          function sendToNative(level, args) {
            try {
              const message = Array.from(args).map(arg => {
                if (typeof arg === 'object') {
                  return JSON.stringify(arg);
                }
                return String(arg);
              }).join(' ');
              
              const logData = {
                level: level,
                message: message,
                timestamp: Date.now()
              };
              
              ConsoleChannel.postMessage(JSON.stringify(logData));
            } catch (e) {
              // 네이티브 전송 실패 시 무시
            }
          }
          
          // 콘솔 메서드 오버라이드
          console.log = function(...args) {
            originalConsole.log.apply(console, args);
            sendToNative('log', args);
          };
          
          console.error = function(...args) {
            originalConsole.error.apply(console, args);
            sendToNative('error', args);
          };
          
          console.warn = function(...args) {
            originalConsole.warn.apply(console, args);
            sendToNative('warn', args);
          };
          
          console.info = function(...args) {
            originalConsole.info.apply(console, args);
            sendToNative('info', args);
          };
          
          console.debug = function(...args) {
            originalConsole.debug.apply(console, args);
            sendToNative('debug', args);
          };
          
          // 전역 에러 핸들러 설정
          window.addEventListener('error', function(event) {
            sendToNative('error', ['Uncaught Error:', event.error?.message || event.message]);
          });
          
          window.addEventListener('unhandledrejection', function(event) {
            sendToNative('error', ['Unhandled Promise Rejection:', event.reason]);
          });
          
          console.log('[WebView Bridge] 로깅 브릿지 설정 완료');
        })();
      ''');
      
      WebViewLogger.debug('로깅 브릿지 설정 완료', source: 'ConsoleLoggingSetup');
    } catch (e) {
      WebViewLogger.error('로깅 브릿지 설정 실패', source: 'ConsoleLoggingSetup', error: e);
    }
  }

  /// 다이얼로그 오버라이드 설정 (alert, confirm, prompt)
  Future<void> _setupDialogOverride() async {
    try {
      await _controller.runJavaScript('''
        (function() {
          // 다이얼로그 응답 대기열
          const dialogPromises = new Map();
          let dialogIdCounter = 0;
          
          // 다이얼로그 응답 이벤트 리스너
          window.addEventListener('dialogResponse', function(event) {
            const response = event.detail;
            const promise = dialogPromises.get(response.id);
            if (promise) {
              promise.resolve(response);
              dialogPromises.delete(response.id);
            }
          });
          
          // Promise 기반 다이얼로그 함수
          function createDialogPromise(type, title, message, defaultValue) {
            return new Promise((resolve) => {
              const id = 'dialog_' + (++dialogIdCounter);
              dialogPromises.set(id, { resolve });
              
              const dialogData = {
                id: id,
                type: type,
                title: title || '',
                message: message || '',
                defaultValue: defaultValue || ''
              };
              
              DialogChannel.postMessage(JSON.stringify(dialogData));
            });
          }
          
          // alert 오버라이드
          window.alert = function(message) {
            return createDialogPromise('alert', '', message, '').then(response => {
              return response.confirmed;
            });
          };
          
          // confirm 오버라이드
          window.confirm = function(message) {
            return createDialogPromise('confirm', '', message, '').then(response => {
              return response.confirmed;
            });
          };
          
          // prompt 오버라이드
          window.prompt = function(message, defaultValue) {
            return createDialogPromise('prompt', '', message, defaultValue || '').then(response => {
              return response.confirmed ? response.value : null;
            });
          };
          
          // 동기적 다이얼로그를 위한 폴백 (호환성)
          const originalAlert = window.alert;
          const originalConfirm = window.confirm;
          const originalPrompt = window.prompt;
          
          // 동기적 호출을 감지하고 경고
          const syncDialogWarning = function(type) {
            console.warn('동기적 ' + type + ' 호출이 감지되었습니다. 네이티브 다이얼로그로 변환됩니다.');
          };
          
          // 기존 함수들을 백업하고 새로운 함수로 교체
          window._originalAlert = originalAlert;
          window._originalConfirm = originalConfirm;
          window._originalPrompt = originalPrompt;
          
          console.log('다이얼로그 오버라이드가 설정되었습니다.');
        })();
      ''');
    } catch (e) {
      WebViewLogger.error('다이얼로그 오버라이드 설정 실패', source: 'DialogOverrideSetup', error: e);
    }
  }

  /// JavaScript 채널 설정
  void setupJavaScriptChannels() {
    try {
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

      // 로깅 채널
      _controller.addJavaScriptChannel(
        'ConsoleChannel',
        onMessageReceived: (JavaScriptMessage message) async {
          await _handleConsoleLog(message.message);
        },
      );

      // 다이얼로그 채널 (alert, confirm, prompt)
      _controller.addJavaScriptChannel(
        'DialogChannel',
        onMessageReceived: (JavaScriptMessage message) async {
          await _handleDialogRequest(message.message);
        },
      );
    } catch (e) {
      // JavaScript 채널 설정 실패 시 에러 로그 출력
      WebViewLogger.error('JavaScript 채널 설정 실패', source: 'JavaScriptChannels', error: e);
    }
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
        // 토큰 갱신은 웹에서 처리하므로 제거
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

  /// 로깅 처리
  Future<void> _handleConsoleLog(String message) async {
    try {
      final data = jsonDecode(message);
      final level = data['level'] as String? ?? 'log';
      final messageText = data['message'] as String? ?? '';
      
      // WebViewLogger를 사용하여 로깅
      switch (level.toLowerCase()) {
        case 'error':
          WebViewLogger.error(
            messageText,
            source: 'WebView',
            error: data['error'],
            stackTrace: data['stackTrace'] != null ? StackTrace.fromString(data['stackTrace']) : null,
          );
          break;
        case 'warn':
        case 'warning':
          WebViewLogger.warn(messageText, source: 'WebView');
          break;
        case 'info':
          WebViewLogger.info(messageText, source: 'WebView');
          break;
        case 'debug':
          WebViewLogger.debug(messageText, source: 'WebView');
          break;
        default:
          WebViewLogger.info(messageText, source: 'WebView');
          break;
      }
    } catch (e) {
      // JSON 파싱 실패 시 원본 메시지를 에러로 로깅
      WebViewLogger.error('Failed to parse console log: $message', source: 'WebView', error: e);
    }
  }

  /// 다이얼로그 요청 처리 (alert, confirm, prompt)
  Future<void> _handleDialogRequest(String message) async {
    try {
      final data = jsonDecode(message);
      final type = data['type'] as String;
      final id = data['id'] as String;
      final title = data['title'] as String? ?? '';
      final messageText = data['message'] as String? ?? '';
      final defaultValue = data['defaultValue'] as String? ?? '';

      switch (type) {
        case 'alert':
          await _showAlert(id, title, messageText);
          break;
        case 'confirm':
          await _showConfirm(id, title, messageText);
          break;
        case 'prompt':
          await _showPrompt(id, title, messageText, defaultValue);
          break;
      }
    } catch (e) {
      WebViewLogger.error('다이얼로그 요청 처리 실패', source: 'DialogHandler', error: e);
      // 에러 발생 시 기본값으로 응답 (ID를 알 수 없으므로 빈 문자열 사용)
      await _sendDialogResponse('', false, '');
    }
  }

  /// Alert 다이얼로그 표시
  Future<void> _showAlert(String id, String title, String message) async {
    final result = await showDialog<bool>(
      context: _context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: title.isNotEmpty ? Text(title) : null,
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
    
    await _sendDialogResponse(id, result ?? false, '');
  }

  /// Confirm 다이얼로그 표시
  Future<void> _showConfirm(String id, String title, String message) async {
    final result = await showDialog<bool>(
      context: _context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: title.isNotEmpty ? Text(title) : null,
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
    
    await _sendDialogResponse(id, result ?? false, '');
  }

  /// Prompt 다이얼로그 표시
  Future<void> _showPrompt(String id, String title, String message, String defaultValue) async {
    final textController = TextEditingController(text: defaultValue);
    
    final result = await showDialog<Map<String, dynamic>>(
      context: _context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: title.isNotEmpty ? Text(title) : null,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop({'confirmed': false, 'value': ''}),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop({
                'confirmed': true, 
                'value': textController.text
              }),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
    
    final confirmed = result?['confirmed'] as bool? ?? false;
    final value = result?['value'] as String? ?? '';
    
    await _sendDialogResponse(id, confirmed, value);
  }

  /// 다이얼로그 응답을 WebView로 전송
  Future<void> _sendDialogResponse(String id, bool confirmed, String value) async {
    await _controller.runJavaScript('''
      (function() {
        try {
          const response = {
            id: ${jsonEncode(id)},
            confirmed: $confirmed,
            value: ${jsonEncode(value)}
          };
          window.dispatchEvent(new CustomEvent('dialogResponse', { 
            detail: response 
          }));
        } catch (e) {
          console.error('Dialog response send failed:', e);
        }
      })();
    ''');
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
    final token = await TokenManager.getAccessToken();
    if (token != null && TokenManager.isTokenValid(token)) {
      await _controller.runJavaScript('''
        (function() {
          try {
            const token = ${jsonEncode(token)};
            window.dispatchEvent(new CustomEvent('tokenReceived', { 
              detail: { token: token } 
            }));
          } catch (e) {
            console.error('Token send failed:', e);
          }
        })();
      ''');
    } else {
      await _controller.runJavaScript('''
        window.dispatchEvent(new CustomEvent('tokenReceived', { 
          detail: { token: null } 
        }));
      ''');
    }
  }

  // 토큰 갱신은 웹에서 처리하므로 제거

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
      (function() {
        try {
          const errorData = ${jsonEncode({'type': type, 'error': error})};
          window.dispatchEvent(new CustomEvent('nativeError', { 
            detail: errorData 
          }));
        } catch (e) {
          console.error('Error send failed:', e);
        }
      })();
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

  /// 화면 정보 조회 (지도 렌더링을 위한 SafeArea 정보 포함)
  Future<Map<String, dynamic>> _getScreenInfo() async {
    try {
      final mediaQuery = MediaQuery.of(_context);
      final statusBarHeight = mediaQuery.padding.top;
      final bottomPadding = mediaQuery.padding.bottom;
      final screenWidth = mediaQuery.size.width;
      final screenHeight = mediaQuery.size.height;
      final devicePixelRatio = mediaQuery.devicePixelRatio;
      
      return {
        'width': screenWidth,
        'height': screenHeight,
        'devicePixelRatio': devicePixelRatio,
        'statusBarHeight': statusBarHeight,
        'bottomPadding': bottomPadding,
        'safeAreaTop': statusBarHeight,
        'safeAreaBottom': bottomPadding,
        'availableHeight': screenHeight - statusBarHeight - bottomPadding,
        'isFullScreen': statusBarHeight == 0,
      };
    } catch (e) {
      // 기본값 반환
      return {
        'width': 375.0,
        'height': 812.0,
        'devicePixelRatio': 2.0,
        'statusBarHeight': 44.0,
        'bottomPadding': 34.0,
        'safeAreaTop': 44.0,
        'safeAreaBottom': 34.0,
        'availableHeight': 734.0,
        'isFullScreen': false,
      };
    }
  }
}

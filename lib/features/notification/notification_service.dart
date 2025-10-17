
import 'package:alter_webview/config/app_config.dart';
import 'package:alter_webview/core/storage/secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

/// Background 메시지 핸들러 (최상위 함수로 정의 필수)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background Message: ${message.messageId}');
  debugPrint('Background Message Title: ${message.notification?.title}');
  debugPrint('Background Message Body: ${message.notification?.body}');
  debugPrint('Background Message Data: ${message.data}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final Dio _dio = Dio();
  
  // iOS APNs 토큰 준비 대기 시간 (밀리초)
  static const int _apnsTokenWaitTimeMs = 1500;
  
  // Android 알림 채널 설정
  static const String _channelId = 'alter_notification_channel';
  static const String _channelName = '알터 알림';
  static const String _channelDescription = '알터 앱의 푸시 알림';

  /// 알림 서비스 초기화 (앱 시작 시 한 번만 호출)
  Future<void> initialize() async {
    // 1. 로컬 알림 플러그인 초기화
    await _initializeLocalNotifications();
    
    // 2. FCM 메시지 리스너 설정
    _setupMessageHandlers();
  }

  /// 로컬 알림 플러그인 초기화
  Future<void> _initializeLocalNotifications() async {
    // Android 설정
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    
    // iOS 설정
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    // 초기화 설정
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    // 알림 탭 이벤트 핸들러 설정
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Android 알림 채널 생성
    if (Platform.isAndroid) {
      final androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
    
    debugPrint('Local notifications initialized');
  }

  /// FCM 메시지 핸들러 설정
  void _setupMessageHandlers() {
    // Foreground 메시지 처리
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Background에서 알림 탭하여 앱 열었을 때 처리
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // 앱이 종료된 상태에서 알림 탭하여 앱 열었을 때 처리
    _handleInitialMessage();
    
    debugPrint('FCM message handlers set up');
  }

  /// Foreground 메시지 처리 (앱이 실행 중일 때)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground Message: ${message.messageId}');
    debugPrint('Foreground Message Title: ${message.notification?.title}');
    debugPrint('Foreground Message Body: ${message.notification?.body}');
    debugPrint('Foreground Message Data: ${message.data}');
    
    // Foreground에서는 직접 로컬 알림을 표시해야 함
    await _showLocalNotification(message);
  }

  /// Background에서 알림 탭하여 앱 열었을 때 처리
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    debugPrint('Message opened app: ${message.messageId}');
    debugPrint('Message Data: ${message.data}');
    
    // TODO: 특정 화면으로 이동하거나 특정 동작 수행
    // 예: Navigator.push(context, MaterialPageRoute(...))
  }

  /// 앱이 종료된 상태에서 알림 탭하여 열었을 때 처리
  Future<void> _handleInitialMessage() async {
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    
    if (initialMessage != null) {
      debugPrint('App opened from terminated state: ${initialMessage.messageId}');
      debugPrint('Initial Message Data: ${initialMessage.data}');
      
      // TODO: 특정 화면으로 이동하거나 특정 동작 수행
    }
  }

  /// 로컬 알림 표시
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    
    // Android 알림 설정
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );
    
    // iOS 알림 설정
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    // 플랫폼별 알림 설정
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // 알림 표시
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  /// 알림 탭 이벤트 처리
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    
    // TODO: 특정 화면으로 이동하거나 특정 동작 수행
  }

  /// 알림 권한 요청 (iOS 및 Android 13+)
  Future<NotificationPermissionStatus> requestNotificationPermission() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      debugPrint('Notification permission status: ${settings.authorizationStatus}');

      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized => NotificationPermissionStatus.granted,
        AuthorizationStatus.provisional => NotificationPermissionStatus.provisional,
        AuthorizationStatus.denied => NotificationPermissionStatus.denied,
        AuthorizationStatus.notDetermined => NotificationPermissionStatus.notDetermined,
      };
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return NotificationPermissionStatus.error;
    }
  }

  /// 알림 권한 상태 확인
  Future<NotificationPermissionStatus> checkNotificationPermission() async {
    try {
      final settings = await _firebaseMessaging.getNotificationSettings();
      
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized => NotificationPermissionStatus.granted,
        AuthorizationStatus.provisional => NotificationPermissionStatus.provisional,
        AuthorizationStatus.denied => NotificationPermissionStatus.denied,
        AuthorizationStatus.notDetermined => NotificationPermissionStatus.notDetermined,
      };
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
      return NotificationPermissionStatus.error;
    }
  }

  /// FCM 토큰을 가져오는 함수
  Future<String?> getFcmToken() async {
    try {
      // iOS에서는 APNs 토큰이 먼저 설정되어야 FCM 토큰을 받을 수 있음
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // APNs 토큰 발급을 위한 대기 시간
        await Future.delayed(const Duration(milliseconds: _apnsTokenWaitTimeMs));
        
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken != null) {
          debugPrint('APNs Token: $apnsToken');
        } else {
          debugPrint('Warning: APNs token not available yet');
        }
      }
      
      final fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $fcmToken');
      return fcmToken;
    } catch (e) {
      debugPrint('FCM Token Error: $e');
      return null;
    }
  }

  /// 서버로 FCM 토큰을 전송하는 함수 (권한 요청 포함)
  /// [accessToken] 파라미터로 직접 전달 가능, null이면 SecureStorage에서 읽음
  Future<void> registerDeviceToken({String? accessToken}) async {
    // 1. 알림 권한 요청
    final permissionStatus = await requestNotificationPermission();
    
    if (permissionStatus != NotificationPermissionStatus.granted &&
        permissionStatus != NotificationPermissionStatus.provisional) {
      debugPrint('Notification permission not granted, skipping token registration.');
      throw Exception('알림 권한이 허용되지 않았습니다.');
    }

    // 2. FCM 토큰 가져오기
    final token = await getFcmToken();
    if (token == null) {
      debugPrint('FCM token is null, skipping registration.');
      throw Exception('FCM 토큰을 가져올 수 없습니다.');
    }

    // 3. 인증 토큰 확인 (파라미터로 전달되지 않으면 SecureStorage에서 읽음)
    String? authToken = accessToken;
    if (authToken == null || authToken.isEmpty) {
      authToken = await SecureStorage.read(AppConfig.accessTokenKey);
    }
    
    if (authToken == null || authToken.isEmpty) {
      debugPrint('Access token not found, skipping device token registration.');
      throw Exception('액세스 토큰이 없습니다.');
    }

    // 4. 플랫폼 타입 결정 (iOS, Android만 허용)
    String devicePlatform;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      devicePlatform = 'IOS';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      devicePlatform = 'ANDROID';
    } else {
      debugPrint('지원하지 않는 플랫폼입니다: $defaultTargetPlatform');
      throw Exception('지원하지 않는 플랫폼입니다. iOS 또는 Android만 지원됩니다.');
    }

    // 5. API 엔드포인트 URL 구성
    final String apiEndpoint = '${AppConfig.apiBaseUrl}/api/app/users/device-token';

    try {
      final response = await _dio.post(
        apiEndpoint,
        data: {
          'deviceToken': token,
          'devicePlatform': devicePlatform,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Device token registered successfully.');
      } else {
        debugPrint('Failed to register device token: ${response.statusCode}');
        throw Exception('FCM 토큰 등록 실패: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final responseData = e.response?.data;
      
      // 서버 응답 에러 메시지 추출
      String errorMessage = '알 수 없는 오류가 발생했습니다.';
      
      if (responseData != null && responseData is Map<String, dynamic>) {
        errorMessage = responseData['message']?.toString() ?? errorMessage;
      }
      
      // 에러 메시지 로깅
      debugPrint('FCM 토큰 등록 실패: $errorMessage');
      
      throw Exception(errorMessage);
    }
  }

  /// FCM 토큰 갱신 리스너 설정
  void setupTokenRefreshListener() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
      // 로그인된 상태에서만 서버에 새 토큰 전송
      _registerDeviceTokenIfLoggedIn();
    });
  }

  /// 로그인된 상태에서만 디바이스 토큰 등록
  Future<void> _registerDeviceTokenIfLoggedIn() async {
    try {
      // 액세스 토큰이 있는지 확인 (로그인 상태 확인)
      final accessToken = await SecureStorage.read(AppConfig.accessTokenKey);
      if (accessToken != null && accessToken.isNotEmpty) {
        await registerDeviceToken(accessToken: accessToken);
      } else {
        debugPrint('사용자가 로그인되지 않음. FCM 토큰 등록 건너뜀.');
      }
    } catch (e) {
      debugPrint('FCM 토큰 등록 실패: $e');
    }
  }
}

/// 알림 권한 상태 Enum
enum NotificationPermissionStatus {
  /// 권한 허용됨
  granted,
  
  /// 임시 권한 허용됨 (iOS)
  provisional,
  
  /// 권한 거부됨
  denied,
  
  /// 권한 결정되지 않음
  notDetermined,
  
  /// 오류 발생
  error,
}

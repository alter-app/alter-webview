
import 'package:alter_webview/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final Dio _dio = Dio();

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
        await Future.delayed(const Duration(milliseconds: 500));
        
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
  Future<void> registerDeviceToken() async {
    // 1. 알림 권한 요청
    final permissionStatus = await requestNotificationPermission();
    
    if (permissionStatus != NotificationPermissionStatus.granted &&
        permissionStatus != NotificationPermissionStatus.provisional) {
      debugPrint('Notification permission not granted, skipping token registration.');
      return;
    }

    // 2. FCM 토큰 가져오기
    final token = await getFcmToken();
    if (token == null) {
      debugPrint('FCM token is null, skipping registration.');
      return;
    }

    // 3. API 엔드포인트 URL 구성
    final String apiEndpoint = '${AppConfig.apiBaseUrl}/api/app/users/device-token';

    try {
      final response = await _dio.post(
        apiEndpoint,
        data: {
          'device_token': token,
          'platform': defaultTargetPlatform.name,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Device token registered successfully.');
      } else {
        debugPrint('Failed to register device token: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('Error registering device token: $e');
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

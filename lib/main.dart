import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/webview/presentation/webview_screen.dart';
import 'config/app_config.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:alter_webview/firebase_options.dart';

import 'package:alter_webview/features/notification/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. .env 파일 로드 (가장 먼저)
    await dotenv.load(fileName: ".env");
    
    // 환경변수 접근 테스트 (값이 없으면 자동으로 예외 발생)
    AppConfig.webUrl;
    AppConfig.apiBaseUrl;
    AppConfig.appName;
    AppConfig.appVersion;

    // 2. Firebase 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 3. FCM 토큰 등록
    await NotificationService().registerDeviceToken();
    
    // 4. 상태바 설정
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    
    // 5. 화면 회전 고정 (세로 모드만)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    runApp(
      const ProviderScope(
        child: AlterWebViewApp(),
      ),
    );
  } catch (e) {
    // 환경변수 오류 시 앱 종료
    debugPrint('앱 시작 실패: $e');
    exit(1);
  }
}

class AlterWebViewApp extends StatelessWidget {
  const AlterWebViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
      ),
      home: const WebViewScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
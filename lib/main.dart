import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/webview/presentation/webview_screen.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 상태바 설정
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );
  
  try {
    // .env 파일 로드
    await dotenv.load(fileName: ".env");
    
    // 환경변수 접근 테스트 (값이 없으면 자동으로 예외 발생)
    AppConfig.webUrl;
    AppConfig.apiBaseUrl;
    AppConfig.appName;
    AppConfig.appVersion;
    AppConfig.locationUpdateInterval;
    AppConfig.locationAccuracy;
    AppConfig.enableJavaScript;
    AppConfig.enableLocalStorage;
    AppConfig.enableGeolocation;
    
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
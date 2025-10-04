import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Web Configuration
  static String get webUrl => dotenv.env['WEB_URL']!;
  static String get apiBaseUrl => dotenv.env['API_BASE_URL']!;
  
  // App Information
  static String get appName => dotenv.env['APP_NAME']!;
  static String get appVersion => dotenv.env['APP_VERSION']!;
  
  
  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
}

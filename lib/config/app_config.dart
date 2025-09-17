import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Web Configuration
  static String get webUrl => dotenv.env['WEB_URL']!;
  static String get apiBaseUrl => dotenv.env['API_BASE_URL']!;
  
  // App Information
  static String get appName => dotenv.env['APP_NAME']!;
  static String get appVersion => dotenv.env['APP_VERSION']!;
  
  // Location Services
  static int get locationUpdateInterval => 
      int.parse(dotenv.env['LOCATION_UPDATE_INTERVAL']!);
  static String get locationAccuracy => 
      dotenv.env['LOCATION_ACCURACY']!;
  
  // WebView Configuration
  static bool get enableJavaScript => 
      dotenv.env['ENABLE_JAVASCRIPT']!.toLowerCase() == 'true';
  static bool get enableLocalStorage => 
      dotenv.env['ENABLE_LOCAL_STORAGE']!.toLowerCase() == 'true';
  static bool get enableGeolocation => 
      dotenv.env['ENABLE_GEOLOCATION']!.toLowerCase() == 'true';
  
  // Storage Keys
  static const String tokenKey = 'jwt_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
}

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// 로그 레벨 열거형
enum LogLevel {
  debug,
  info,
  warn,
  error,
}

/// 로그 메시지 구조체
class LogMessage {
  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final String? source;
  
  const LogMessage({
    required this.level,
    required this.message,
    required this.timestamp,
    this.source,
  });
}

/// 웹뷰 콘솔 로깅을 위한 전용 로거
class WebViewLogger {
  static const String _tag = 'WebView';
  
  /// 로그 메시지 정리 (이모지 제거 및 필수 값만 추출)
  static String _cleanLogMessage(String message) {
    if (message.isEmpty) return message;
    
    // 이모지 제거 (유니코드 범위)
    String cleanMessage = message.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}]', unicode: true), '');
    cleanMessage = cleanMessage.replaceAll(RegExp(r'[\u{1F300}-\u{1F5FF}]', unicode: true), '');
    cleanMessage = cleanMessage.replaceAll(RegExp(r'[\u{1F680}-\u{1F6FF}]', unicode: true), '');
    cleanMessage = cleanMessage.replaceAll(RegExp(r'[\u{1F1E0}-\u{1F1FF}]', unicode: true), '');
    cleanMessage = cleanMessage.replaceAll(RegExp(r'[\u{2600}-\u{26FF}]', unicode: true), '');
    cleanMessage = cleanMessage.replaceAll(RegExp(r'[\u{2700}-\u{27BF}]', unicode: true), '');
    
    // 연속된 공백 제거
    cleanMessage = cleanMessage.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleanMessage;
  }
  
  /// 로그 메시지 처리
  static void log({
    required LogLevel level,
    required String message,
    String? source,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // info 레벨은 로깅하지 않음
    if (level == LogLevel.info) {
      return;
    }
    
    final cleanMessage = _cleanLogMessage(message);
    final timestamp = DateTime.now();
    
    // 로그 메시지 객체 생성
    final logMessage = LogMessage(
      level: level,
      message: cleanMessage,
      timestamp: timestamp,
      source: source,
    );
    
    // 개발 모드에서만 상세 로깅
    if (kDebugMode) {
      _logToDebugConsole(logMessage, error, stackTrace);
    }
    
    // 릴리즈 모드에서도 에러는 로깅
    if (level == LogLevel.error) {
      _logToReleaseConsole(logMessage, error, stackTrace);
    }
  }
  
  /// 개발 모드 콘솔 로깅
  static void _logToDebugConsole(LogMessage logMessage, Object? error, StackTrace? stackTrace) {
    final levelPrefix = _getLevelPrefix(logMessage.level);
    final sourceInfo = logMessage.source != null ? ' [${logMessage.source}]' : '';
    final timestamp = _formatTimestamp(logMessage.timestamp);
    
    final logText = '[$timestamp]$sourceInfo $levelPrefix ${logMessage.message}';
    
    switch (logMessage.level) {
      case LogLevel.debug:
        developer.log(logText, name: _tag, level: 500);
        break;
      case LogLevel.info:
        developer.log(logText, name: _tag, level: 800);
        break;
      case LogLevel.warn:
        developer.log(logText, name: _tag, level: 900);
        break;
      case LogLevel.error:
        developer.log(
          logText,
          name: _tag,
          level: 1000,
          error: error,
          stackTrace: stackTrace,
        );
        break;
    }
  }
  
  /// 릴리즈 모드 콘솔 로깅
  static void _logToReleaseConsole(LogMessage logMessage, Object? error, StackTrace? stackTrace) {
    final levelPrefix = _getLevelPrefix(logMessage.level);
    final sourceInfo = logMessage.source != null ? ' [${logMessage.source}]' : '';
    final timestamp = _formatTimestamp(logMessage.timestamp);
    
    final logText = '[$timestamp]$sourceInfo $levelPrefix ${logMessage.message}';
    
    // 릴리즈 모드에서는 debugPrint 사용
    debugPrint(logText);
    
    if (error != null) {
      debugPrint('Error: $error');
    }
    
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }
  
  /// 로그 레벨 접두사 반환
  static String _getLevelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '[DEBUG]';
      case LogLevel.info:
        return '[INFO]';
      case LogLevel.warn:
        return '[WARN]';
      case LogLevel.error:
        return '[ERROR]';
    }
  }
  
  /// 타임스탬프 포맷팅
  static String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
           '${timestamp.minute.toString().padLeft(2, '0')}:'
           '${timestamp.second.toString().padLeft(2, '0')}.'
           '${timestamp.millisecond.toString().padLeft(3, '0')}';
  }
  
  /// 편의 메서드들
  static void debug(String message, {String? source}) {
    log(level: LogLevel.debug, message: message, source: source);
  }
  
  static void info(String message, {String? source}) {
    log(level: LogLevel.info, message: message, source: source);
  }
  
  static void warn(String message, {String? source}) {
    log(level: LogLevel.warn, message: message, source: source);
  }
  
  static void error(String message, {String? source, Object? error, StackTrace? stackTrace}) {
    log(level: LogLevel.error, message: message, source: source, error: error, stackTrace: stackTrace);
  }
}
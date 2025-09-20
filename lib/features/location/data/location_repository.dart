import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationRepository {
  /// 위치 권한 요청
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status == PermissionStatus.granted;
  }

  /// 위치 권한 상태 확인
  Future<bool> isLocationPermissionGranted() async {
    final status = await Permission.location.status;
    return status == PermissionStatus.granted;
  }

  /// 현재 위치 조회
  Future<Position> getCurrentPosition() async {
    try {
      // 위치 서비스 활성화 확인
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationServiceDisabledException();
      }

      // 권한 확인
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestPermission = await Geolocator.requestPermission();
        if (requestPermission == LocationPermission.denied) {
          throw LocationPermissionDeniedException();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw LocationPermissionDeniedForeverException();
      }

      // 현재 위치 조회
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      throw LocationException('현재 위치를 가져올 수 없습니다.');
    }
  }

  /// 위치 스트림 구독
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10미터마다 업데이트
      ),
    );
  }

  /// 두 지점 간 거리 계산 (미터)
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// 위치 데이터를 JSON 형태로 변환
  Map<String, dynamic> positionToJson(Position position) {
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'speed': position.speed,
      'heading': position.heading,
      'timestamp': position.timestamp.millisecondsSinceEpoch,
    };
  }
}

// Custom Exceptions
class LocationException implements Exception {
  final String message;
  LocationException(this.message);
  
  @override
  String toString() => 'LocationException: $message';
}

class LocationServiceDisabledException extends LocationException {
  LocationServiceDisabledException() : super('위치 서비스가 비활성화되어 있습니다.');
}

class LocationPermissionDeniedException extends LocationException {
  LocationPermissionDeniedException() : super('위치 권한이 거부되었습니다.');
}

class LocationPermissionDeniedForeverException extends LocationException {
  LocationPermissionDeniedForeverException() 
      : super('위치 권한이 영구적으로 거부되었습니다.');
}

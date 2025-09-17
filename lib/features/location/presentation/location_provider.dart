import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../data/location_repository.dart';

// Location Repository Provider
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

// Location State
class LocationState {
  final bool isLoading;
  final bool hasPermission;
  final Position? currentPosition;
  final String? error;
  final bool isTracking;

  const LocationState({
    this.isLoading = false,
    this.hasPermission = false,
    this.currentPosition,
    this.error,
    this.isTracking = false,
  });

  LocationState copyWith({
    bool? isLoading,
    bool? hasPermission,
    Position? currentPosition,
    String? error,
    bool? isTracking,
  }) {
    return LocationState(
      isLoading: isLoading ?? this.isLoading,
      hasPermission: hasPermission ?? this.hasPermission,
      currentPosition: currentPosition ?? this.currentPosition,
      error: error,
      isTracking: isTracking ?? this.isTracking,
    );
  }
}

// Location Notifier
class LocationNotifier extends StateNotifier<LocationState> {
  final LocationRepository _locationRepository;

  LocationNotifier(this._locationRepository) : super(const LocationState()) {
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final hasPermission = await _locationRepository.isLocationPermissionGranted();
    state = state.copyWith(hasPermission: hasPermission);
  }

  Future<void> requestPermission() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final granted = await _locationRepository.requestLocationPermission();
      state = state.copyWith(
        isLoading: false,
        hasPermission: granted,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> getCurrentLocation() async {
    if (!state.hasPermission) {
      state = state.copyWith(error: 'Location permission not granted');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final position = await _locationRepository.getCurrentPosition();
      state = state.copyWith(
        isLoading: false,
        currentPosition: position,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void startTracking() {
    if (!state.hasPermission) {
      state = state.copyWith(error: 'Location permission not granted');
      return;
    }

    state = state.copyWith(isTracking: true, error: null);
    
    _locationRepository.getPositionStream().listen(
      (position) {
        state = state.copyWith(currentPosition: position);
      },
      onError: (error) {
        state = state.copyWith(
          error: error.toString(),
          isTracking: false,
        );
      },
    );
  }

  void stopTracking() {
    state = state.copyWith(isTracking: false);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Location Provider
final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  final locationRepository = ref.watch(locationRepositoryProvider);
  return LocationNotifier(locationRepository);
});

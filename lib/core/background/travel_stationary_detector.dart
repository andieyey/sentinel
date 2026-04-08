import 'package:geolocator/geolocator.dart';

class TravelLocationSample {
  const TravelLocationSample({
    required this.latitude,
    required this.longitude,
    required this.speedMetersPerSecond,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double speedMetersPerSecond;
  final DateTime timestamp;

  factory TravelLocationSample.fromPosition(Position position) {
    return TravelLocationSample(
      latitude: position.latitude,
      longitude: position.longitude,
      speedMetersPerSecond: position.speed,
      timestamp: position.timestamp,
    );
  }
}

class TravelStationaryDetector {
  TravelStationaryDetector({
    this.stationaryWarmup = const Duration(seconds: 30),
    this.stationaryDuration = const Duration(minutes: 5),
    this.stationaryDistanceThresholdMeters = 20,
    this.movingSpeedThresholdMetersPerSecond = 1.5,
  });

  final Duration stationaryWarmup;
  final Duration stationaryDuration;
  final double stationaryDistanceThresholdMeters;
  final double movingSpeedThresholdMetersPerSecond;

  TravelLocationSample? _anchor;
  DateTime? _stationarySince;
  bool _didTrigger = false;

  bool observe({
    required TravelLocationSample sample,
    required bool hasTravelTask,
  }) {
    if (!hasTravelTask) {
      reset();
      return false;
    }

    if (sample.speedMetersPerSecond > movingSpeedThresholdMetersPerSecond) {
      _anchor = sample;
      _stationarySince = null;
      _didTrigger = false;
      return false;
    }

    final anchor = _anchor;
    if (anchor == null) {
      _anchor = sample;
      _stationarySince = sample.timestamp;
      _didTrigger = false;
      return false;
    }

    final distanceMeters = Geolocator.distanceBetween(
      anchor.latitude,
      anchor.longitude,
      sample.latitude,
      sample.longitude,
    );

    if (distanceMeters > stationaryDistanceThresholdMeters) {
      _anchor = sample;
      _stationarySince = sample.timestamp;
      _didTrigger = false;
      return false;
    }

    _stationarySince ??= sample.timestamp;
    final stationaryElapsed = sample.timestamp.difference(_stationarySince!);
    if (stationaryElapsed < stationaryWarmup + stationaryDuration) {
      return false;
    }

    if (_didTrigger) {
      return false;
    }

    _didTrigger = true;
    return true;
  }

  void reset() {
    _anchor = null;
    _stationarySince = null;
    _didTrigger = false;
  }
}
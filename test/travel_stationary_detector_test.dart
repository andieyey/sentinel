import 'package:flutter_test/flutter_test.dart';

import 'package:sentinel/core/background/travel_stationary_detector.dart';

TravelLocationSample _sample({
  required double latitude,
  required double longitude,
  required double speedMetersPerSecond,
  required DateTime timestamp,
}) {
  return TravelLocationSample(
    latitude: latitude,
    longitude: longitude,
    speedMetersPerSecond: speedMetersPerSecond,
    timestamp: timestamp,
  );
}

void main() {
  group('TravelStationaryDetector', () {
    test('does not trigger on a brief stop like a red light', () {
      final detector = TravelStationaryDetector(
        stationaryWarmup: const Duration(seconds: 10),
        stationaryDuration: const Duration(minutes: 1),
        stationaryDistanceThresholdMeters: 20,
        movingSpeedThresholdMetersPerSecond: 1.5,
      );

      final start = DateTime(2026, 4, 9, 10, 0);

      expect(
        detector.observe(
          sample: _sample(
            latitude: 40.0,
            longitude: -73.0,
            speedMetersPerSecond: 0.0,
            timestamp: start,
          ),
          hasTravelTask: true,
        ),
        isFalse,
      );

      expect(
        detector.observe(
          sample: _sample(
            latitude: 40.00001,
            longitude: -73.00001,
            speedMetersPerSecond: 0.0,
            timestamp: start.add(const Duration(seconds: 45)),
          ),
          hasTravelTask: true,
        ),
        isFalse,
      );
    });

    test('triggers only after stationary warmup and hold are satisfied', () {
      final detector = TravelStationaryDetector(
        stationaryWarmup: const Duration(seconds: 10),
        stationaryDuration: const Duration(minutes: 1),
        stationaryDistanceThresholdMeters: 20,
        movingSpeedThresholdMetersPerSecond: 1.5,
      );

      final start = DateTime(2026, 4, 9, 10, 0);

      expect(
        detector.observe(
          sample: _sample(
            latitude: 40.0,
            longitude: -73.0,
            speedMetersPerSecond: 0.0,
            timestamp: start,
          ),
          hasTravelTask: true,
        ),
        isFalse,
      );

      expect(
        detector.observe(
          sample: _sample(
            latitude: 40.00001,
            longitude: -73.00001,
            speedMetersPerSecond: 0.1,
            timestamp: start.add(const Duration(seconds: 30)),
          ),
          hasTravelTask: true,
        ),
        isFalse,
      );

      expect(
        detector.observe(
          sample: _sample(
            latitude: 40.00001,
            longitude: -73.00001,
            speedMetersPerSecond: 0.0,
            timestamp: start.add(const Duration(seconds: 75)),
          ),
          hasTravelTask: true,
        ),
        isTrue,
      );

      expect(
        detector.observe(
          sample: _sample(
            latitude: 40.00001,
            longitude: -73.00001,
            speedMetersPerSecond: 0.0,
            timestamp: start.add(const Duration(seconds: 90)),
          ),
          hasTravelTask: true,
        ),
        isFalse,
      );
    });

    test('moving again resets the stationary window', () {
      final detector = TravelStationaryDetector(
        stationaryWarmup: const Duration(seconds: 10),
        stationaryDuration: const Duration(minutes: 1),
        stationaryDistanceThresholdMeters: 20,
        movingSpeedThresholdMetersPerSecond: 1.5,
      );

      final start = DateTime(2026, 4, 9, 10, 0);

      expect(
        detector.observe(
          sample: _sample(
            latitude: 40.0,
            longitude: -73.0,
            speedMetersPerSecond: 0.0,
            timestamp: start,
          ),
          hasTravelTask: true,
        ),
        isFalse,
      );

      expect(
        detector.observe(
          sample: _sample(
            latitude: 40.001,
            longitude: -73.001,
            speedMetersPerSecond: 5.0,
            timestamp: start.add(const Duration(seconds: 20)),
          ),
          hasTravelTask: true,
        ),
        isFalse,
      );

      expect(
        detector.observe(
          sample: _sample(
            latitude: 40.001,
            longitude: -73.001,
            speedMetersPerSecond: 0.0,
            timestamp: start.add(const Duration(seconds: 90)),
          ),
          hasTravelTask: true,
        ),
        isFalse,
      );
    });
  });
}

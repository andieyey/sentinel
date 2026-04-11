import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackgroundStatus {
  const BackgroundStatus({required this.timestamp, required this.source});

  final DateTime timestamp;
  final String source;

  factory BackgroundStatus.initial() {
    return BackgroundStatus(timestamp: DateTime.now(), source: 'bootstrap');
  }
}

class BackgroundRecalculationEvent {
  const BackgroundRecalculationEvent({
    required this.timestamp,
    required this.triggerSource,
    required this.changedTaskCount,
    required this.totalTaskCount,
    required this.hasError,
    required this.isThrottled,
    this.failingTravelTaskTitle,
    this.totalDayDelayMinutes,
    this.sleepAtRiskTime,
    this.stationaryMinutes,
    this.throttleKey,
    this.minimumIntervalMs,
  });

  final DateTime timestamp;
  final String triggerSource;
  final int changedTaskCount;
  final int totalTaskCount;
  final bool hasError;
  final bool isThrottled;
  final String? failingTravelTaskTitle;
  final int? totalDayDelayMinutes;
  final DateTime? sleepAtRiskTime;
  final int? stationaryMinutes;
  final String? throttleKey;
  final int? minimumIntervalMs;

  factory BackgroundRecalculationEvent.fromMap(Map<String, dynamic> payload) {
    final timestampRaw = payload['timestamp'] as String?;
    final triggerSource = payload['triggerSource'] as String? ?? 'unknown';
    final changedTaskCount = payload['changedTaskCount'] as int? ?? 0;
    final totalTaskCount = payload['totalTaskCount'] as int? ?? 0;
    final hasError = payload['hasError'] as bool? ?? false;
    final isThrottled = payload['isThrottled'] as bool? ?? false;
    final failingTravelTaskTitle = payload['failingTravelTaskTitle'] as String?;
    final totalDayDelayMinutes = payload['totalDayDelayMinutes'] as int?;
    final sleepAtRiskTimeRaw = payload['sleepAtRiskTime'] as String?;
    final stationaryMinutes = payload['stationaryMinutes'] as int?;
    final throttleKey = payload['throttleKey'] as String?;
    final minimumIntervalMs = payload['minimumIntervalMs'] as int?;

    return BackgroundRecalculationEvent(
      timestamp: DateTime.tryParse(timestampRaw ?? '') ?? DateTime.now(),
      triggerSource: triggerSource,
      changedTaskCount: changedTaskCount,
      totalTaskCount: totalTaskCount,
      hasError: hasError,
      isThrottled: isThrottled,
      failingTravelTaskTitle: failingTravelTaskTitle,
      totalDayDelayMinutes: totalDayDelayMinutes,
      sleepAtRiskTime: DateTime.tryParse(sleepAtRiskTimeRaw ?? ''),
      stationaryMinutes: stationaryMinutes,
      throttleKey: throttleKey,
      minimumIntervalMs: minimumIntervalMs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'triggerSource': triggerSource,
      'changedTaskCount': changedTaskCount,
      'totalTaskCount': totalTaskCount,
      'hasError': hasError,
      'isThrottled': isThrottled,
      'failingTravelTaskTitle': failingTravelTaskTitle,
      'totalDayDelayMinutes': totalDayDelayMinutes,
      'sleepAtRiskTime': sleepAtRiskTime?.toIso8601String(),
      'stationaryMinutes': stationaryMinutes,
      'throttleKey': throttleKey,
      'minimumIntervalMs': minimumIntervalMs,
    };
  }
}

class BackgroundGpsTick {
  const BackgroundGpsTick({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.source,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String source;
}

class BackgroundGpsStatus {
  const BackgroundGpsStatus({
    required this.timestamp,
    required this.state,
    this.permission,
  });

  final DateTime timestamp;
  final String state;
  final String? permission;
}

final backgroundStatusProvider = StreamProvider<BackgroundStatus>((ref) {
  final service = FlutterBackgroundService();
  final controller = StreamController<BackgroundStatus>.broadcast();

  controller.add(BackgroundStatus.initial());

  final subscription = service.on('status_update').listen((payload) {
    final timestampRaw = payload?['timestamp'] as String?;
    final source = payload?['source'] as String? ?? 'background_service';
    controller.add(
      BackgroundStatus(
        timestamp: DateTime.tryParse(timestampRaw ?? '') ?? DateTime.now(),
        source: source,
      ),
    );
  });

  ref.onDispose(() async {
    await subscription.cancel();
    await controller.close();
  });

  return controller.stream;
});

final backgroundRecalculationProvider =
    StreamProvider<BackgroundRecalculationEvent>((ref) {
      final service = FlutterBackgroundService();
      final controller =
          StreamController<BackgroundRecalculationEvent>.broadcast();

      final subscription = service.on('recalculation_complete').listen((
        payload,
      ) {
        if (payload == null) {
          return;
        }

        controller.add(BackgroundRecalculationEvent.fromMap(payload));
      });

      final throttledSubscription = service
          .on('recalculation_throttled')
          .listen((payload) {
            final timestampRaw = payload?['timestamp'] as String?;
            final triggerSource =
                payload?['triggerSource'] as String? ?? 'unknown';
            final throttleKey = payload?['throttleKey'] as String?;
            final minimumIntervalMs = payload?['minimumIntervalMs'] as int?;

            controller.add(
              BackgroundRecalculationEvent.fromMap({
                'timestamp': timestampRaw,
                'triggerSource': triggerSource,
                'changedTaskCount': 0,
                'totalTaskCount': 0,
                'hasError': false,
                'isThrottled': true,
                'failingTravelTaskTitle': null,
                'totalDayDelayMinutes': null,
                'sleepAtRiskTime': null,
                'stationaryMinutes': null,
                'throttleKey': throttleKey,
                'minimumIntervalMs': minimumIntervalMs,
              }),
            );
          });

      ref.onDispose(() async {
        await subscription.cancel();
        await throttledSubscription.cancel();
        await controller.close();
      });

      return controller.stream;
    });

final backgroundGpsTickProvider = StreamProvider<BackgroundGpsTick>((ref) {
  final service = FlutterBackgroundService();
  final controller = StreamController<BackgroundGpsTick>.broadcast();

  final subscription = service.on('gps_tick').listen((payload) {
    final timestampRaw = payload?['timestamp'] as String?;
    final latitude = (payload?['latitude'] as num?)?.toDouble();
    final longitude = (payload?['longitude'] as num?)?.toDouble();
    final source = payload?['source'] as String? ?? 'unknown';

    if (latitude == null || longitude == null) {
      return;
    }

    controller.add(
      BackgroundGpsTick(
        timestamp: DateTime.tryParse(timestampRaw ?? '') ?? DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        source: source,
      ),
    );
  });

  ref.onDispose(() async {
    await subscription.cancel();
    await controller.close();
  });

  return controller.stream;
});

final backgroundGpsStatusProvider = StreamProvider<BackgroundGpsStatus>((ref) {
  final service = FlutterBackgroundService();
  final controller = StreamController<BackgroundGpsStatus>.broadcast();

  final subscription = service.on('gps_status').listen((payload) {
    final timestampRaw = payload?['timestamp'] as String?;
    final state = payload?['state'] as String? ?? 'unknown';
    final permission = payload?['permission'] as String?;

    controller.add(
      BackgroundGpsStatus(
        timestamp: DateTime.tryParse(timestampRaw ?? '') ?? DateTime.now(),
        state: state,
        permission: permission,
      ),
    );
  });

  ref.onDispose(() async {
    await subscription.cancel();
    await controller.close();
  });

  return controller.stream;
});

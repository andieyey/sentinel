import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../scheduler/background_scheduler_orchestrator.dart';
import '../scheduler/priority_mode.dart';
import '../scheduler/priority_mode_persistence.dart';
import '../../features/scheduler/domain/conflict_solver.dart';
import 'notification_bridge.dart';
import 'travel_stationary_detector.dart';

class SentinelBackgroundService {
  SentinelBackgroundService._();

  static bool _configured = false;

  static Future<void> initialize() async {
    if (_configured) {
      return;
    }

    await NotificationBridge.initialize();
    await NotificationBridge.requestPermissions();

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: true,
        isForegroundMode: true,
        autoStartOnBoot: true,
        notificationChannelId: NotificationBridge.channelId,
        initialNotificationTitle: 'Project Sentinel',
        initialNotificationContent: 'Brain is calibrating volatility stream.',
        foregroundServiceNotificationId:
            NotificationBridge.foregroundNotificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );

    _configured = true;

    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  await NotificationBridge.initialize();
  await NotificationBridge.showStatusUpdate(
    timestamp: DateTime.now(),
    source: 'ios_background_fetch',
  );

  return true;
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  await NotificationBridge.initialize();

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title: 'Sentinel Brain Active',
      content: 'Status Update: ${DateTime.now().toLocal()} from service_bootstrap',
    );

    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
  }

  final monitor = _BrainSignalMonitor(service);
  await monitor.start();

  service.on('stopService').listen((_) async {
    await monitor.dispose();
    service.stopSelf();
  });
}

class _BrainSignalMonitor {
  _BrainSignalMonitor(this._service);

  static const Duration _timeTickMinimumInterval = Duration(seconds: 50);
  static const Duration _gpsDebounceDuration = Duration(seconds: 8);
  static const Duration _gpsMinimumInterval = Duration(seconds: 30);
  static const Duration _gpsPollingInterval = Duration(seconds: 20);

  final ServiceInstance _service;
  final BackgroundSchedulerOrchestrator _scheduler =
      BackgroundSchedulerOrchestrator();
    final TravelStationaryDetector _travelStationaryDetector =
      TravelStationaryDetector();

  Timer? _statusTimer;
  Timer? _gpsDebounceTimer;
  Timer? _gpsPollingTimer;
  StreamSubscription<DateTime>? _timeSubscription;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<Map<String, dynamic>?>? _priorityModeSubscription;
  final Map<String, DateTime> _lastRecalculationAt = {};
  double? _pendingLatitude;
  double? _pendingLongitude;

  Future<void> start() async {
    final restoredMode = await PriorityModePersistence.load();
    ConflictPolicy.isSleepPriority = restoredMode.isSleepPriority;

    await _scheduler.initialize();

    await _emitStatus(source: 'service_start');
    await _runRecalculation(triggerSource: 'service_start', isForce: true);

    _statusTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      await _emitStatus(source: 'timer_heartbeat');
      await _runRecalculation(triggerSource: 'timer_heartbeat', isForce: true);
    });

    _timeSubscription =
        Stream<DateTime>.periodic(
          const Duration(minutes: 1),
          (_) => DateTime.now(),
        ).listen((now) {
          _service.invoke('time_tick', {'timestamp': now.toIso8601String()});
          unawaited(
            _runRecalculation(
              triggerSource: 'time_tick',
              minimumInterval: _timeTickMinimumInterval,
              throttleKey: 'time_tick',
            ),
          );
        });

    _priorityModeSubscription = _service.on('priority_mode_update').listen((
      payload,
    ) {
      final nextMode = payload?['isSleepPriority'];
      if (nextMode is bool) {
        final mode = priorityModeFromSleepFlag(nextMode);
        ConflictPolicy.isSleepPriority = mode.isSleepPriority;
        unawaited(PriorityModePersistence.save(mode));
        unawaited(
          _runRecalculation(
            triggerSource: 'priority_mode_update',
            isForce: true,
          ),
        );
      }
    });

    await _startLocationStream();

    // Stream updates can be sparse on emulator/fused provider; polling keeps
    // location signals flowing for deterministic testing.
    _gpsPollingTimer = Timer.periodic(_gpsPollingInterval, (_) {
      unawaited(_pollCurrentPosition());
    });
  }

  Future<void> _emitStatus({required String source}) async {
    final now = DateTime.now();
    if (_service case final AndroidServiceInstance androidService) {
      await androidService.setForegroundNotificationInfo(
        title: 'Sentinel Brain Active',
        content: 'Status Update: ${now.toLocal()} from $source',
      );
    } else {
      await NotificationBridge.showStatusUpdate(
        timestamp: now,
        source: source,
        notificationId: NotificationBridge.foregroundNotificationId,
        ongoing: true,
      );
    }
    _service.invoke('status_update', {
      'timestamp': now.toIso8601String(),
      'source': source,
    });
  }

  Future<void> _startLocationStream() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _service.invoke('gps_status', {
          'timestamp': DateTime.now().toIso8601String(),
          'state': 'service_disabled',
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _service.invoke('gps_status', {
          'timestamp': DateTime.now().toIso8601String(),
          'state': 'permission_denied',
          'permission': permission.name,
        });
        return;
      }

      _service.invoke('gps_status', {
        'timestamp': DateTime.now().toIso8601String(),
        'state': 'stream_starting',
        'permission': permission.name,
      });

        final locationSettings = Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
              intervalDuration: Duration(seconds: 3),
              forceLocationManager: true,
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
            );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((position) {
            _service.invoke('gps_tick', {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'timestamp': DateTime.now().toIso8601String(),
              'source': 'stream',
            });

            _service.invoke('gps_status', {
              'timestamp': DateTime.now().toIso8601String(),
              'state': 'tick_received',
            });

            // Helpful for validating location flow during emulator testing.
            developer.log(
              'GPS tick lat=${position.latitude} lon=${position.longitude}',
              name: 'SentinelBG',
            );

            _scheduleGpsRecalculation(position);
            unawaited(_evaluateTravelStationaryTrigger(position));
          });
    } catch (_) {
      // Permission and service state are expected to vary by user/device.
      _service.invoke('gps_status', {
        'timestamp': DateTime.now().toIso8601String(),
        'state': 'stream_error',
      });
    }
  }

  Future<void> _pollCurrentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      _service.invoke('gps_tick', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'poll',
      });

      _service.invoke('gps_status', {
        'timestamp': DateTime.now().toIso8601String(),
        'state': 'poll_tick_received',
      });

      _scheduleGpsRecalculation(position);
      unawaited(_evaluateTravelStationaryTrigger(position));
    } catch (_) {
      _service.invoke('gps_status', {
        'timestamp': DateTime.now().toIso8601String(),
        'state': 'poll_error',
      });
    }
  }

  void _scheduleGpsRecalculation(Position position) {
    _pendingLatitude = position.latitude;
    _pendingLongitude = position.longitude;

    _gpsDebounceTimer?.cancel();
    _gpsDebounceTimer = Timer(_gpsDebounceDuration, () {
      unawaited(
        _runRecalculation(
          triggerSource: 'gps_tick_debounced',
          latitude: _pendingLatitude,
          longitude: _pendingLongitude,
          minimumInterval: _gpsMinimumInterval,
          throttleKey: 'gps_tick',
        ),
      );
    });
  }

  Future<void> _evaluateTravelStationaryTrigger(Position position) async {
    final hasTravelTask = await _scheduler.hasInProgressTravelTask();
    final sample = TravelLocationSample.fromPosition(position);
    if (!_travelStationaryDetector.observe(
      sample: sample,
      hasTravelTask: hasTravelTask,
    )) {
      return;
    }

    final now = sample.timestamp;
    _service.invoke('gps_status', {
      'timestamp': now.toIso8601String(),
      'state': 'travel_stationary_recalc_trigger',
      'stationaryMs': (
        _travelStationaryDetector.stationaryWarmup +
        _travelStationaryDetector.stationaryDuration
      ).inMilliseconds,
    });

    await _runRecalculation(
      triggerSource: 'gps_travel_stationary_5m',
      latitude: sample.latitude,
      longitude: sample.longitude,
      throttleKey: 'gps_travel_stationary',
      isForce: true,
    );
  }

  Future<void> _runRecalculation({
    required String triggerSource,
    double? latitude,
    double? longitude,
    Duration? minimumInterval,
    String throttleKey = 'default',
    bool isForce = false,
  }) async {
    final now = DateTime.now();
    final lastRunAt = _lastRecalculationAt[throttleKey];

    if (!isForce && minimumInterval != null && lastRunAt != null) {
      final elapsed = now.difference(lastRunAt);
      if (elapsed < minimumInterval) {
        _service.invoke('recalculation_throttled', {
          'timestamp': now.toIso8601String(),
          'triggerSource': triggerSource,
          'throttleKey': throttleKey,
          'minimumIntervalMs': minimumInterval.inMilliseconds,
        });
        developer.log(
          'Recalc throttled trigger=$triggerSource key=$throttleKey intervalMs=${minimumInterval.inMilliseconds}',
          name: 'SentinelBG',
        );
        return;
      }
    }

    final result = await _scheduler.recalculate(
      now: now,
      triggerSource: triggerSource,
      latitude: latitude,
      longitude: longitude,
    );
    _lastRecalculationAt[throttleKey] = now;

    _service.invoke('recalculation_complete', {
      'timestamp': now.toIso8601String(),
      'triggerSource': result.triggerSource,
      'changedTaskCount': result.changedTaskCount,
      'totalTaskCount': result.totalTaskCount,
      'hasError': result.hasError,
    });
    developer.log(
      'Recalc complete trigger=${result.triggerSource} changed=${result.changedTaskCount}/${result.totalTaskCount}',
      name: 'SentinelBG',
    );
  }

  Future<void> dispose() async {
    _statusTimer?.cancel();
    _gpsDebounceTimer?.cancel();
    _gpsPollingTimer?.cancel();
    await _timeSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _priorityModeSubscription?.cancel();
    await _scheduler.dispose();
  }
}

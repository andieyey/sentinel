import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_bridge.dart';

const String sentinelStatusTaskName = 'sentinel_status_update';
const bool _workmanagerDebugNotifications = bool.fromEnvironment(
  'SENTINEL_WORKMANAGER_DEBUG_NOTIFICATIONS',
  defaultValue: false,
);

@pragma('vm:entry-point')
void sentinelWorkmanagerDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    await NotificationBridge.initialize();
    await NotificationBridge.showStatusUpdate(
      timestamp: DateTime.now(),
      source: inputData?['source'] as String? ?? 'workmanager',
    );

    return Future.value(true);
  });
}

class SentinelWorkmanagerDispatcher {
  SentinelWorkmanagerDispatcher._();

  static bool _initialized = false;

  static Future<void> initializeAndRegister() async {
    if (_initialized) {
      return;
    }

    await Workmanager().initialize(
      sentinelWorkmanagerDispatcher,
      isInDebugMode: _workmanagerDebugNotifications,
    );

    _initialized = true;

    // Android periodic workers have a minimum 15 minute cadence.
    await Workmanager().registerPeriodicTask(
      'sentinel_periodic_status_worker',
      sentinelStatusTaskName,
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 10),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.not_required),
      inputData: const {'source': 'workmanager_periodic'},
    );
  }
}

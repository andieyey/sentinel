import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../background/background_status.dart';
import '../scheduler/priority_mode.dart';
import 'activitykit_bridge.dart';

class LockScreenAssistantController {
  LockScreenAssistantController._();

  static final LockScreenAssistantController instance =
      LockScreenAssistantController._();

  static const String _liveActivityIdKey = 'sentinel.live_activity_id';

  bool? _activityKitSupported;

  Future<void> syncHeartbeat({
    required BackgroundStatus status,
    required String modeLabel,
  }) async {
    await _sync(
      payload: _makePayload(
        statusLine: 'Heartbeat from ${status.source}',
        modeLabel: modeLabel,
        changedTaskCount: 0,
        totalTaskCount: 0,
        updatedAt: status.timestamp,
        progress: 0.0,
      ),
    );
  }

  Future<void> syncRecalculation({
    required BackgroundRecalculationEvent event,
    required PriorityMode mode,
  }) async {
    await _sync(
      payload: _makePayload(
        statusLine:
            'Adjusted ${event.changedTaskCount}/${event.totalTaskCount} tasks',
        modeLabel: mode.label,
        changedTaskCount: event.changedTaskCount,
        totalTaskCount: event.totalTaskCount,
        updatedAt: event.timestamp,
        progress: event.totalTaskCount == 0
            ? 0.0
            : event.changedTaskCount / event.totalTaskCount,
      ),
    );
  }

  Future<void> endActivity() async {
    if (!await _isSupported()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final activityId = prefs.getString(_liveActivityIdKey);
    if (activityId == null) {
      return;
    }

    final ended = await ActivityKitBridge.endActivity(activityId);
    if (ended) {
      await prefs.remove(_liveActivityIdKey);
    }
  }

  Future<void> _sync({required Map<String, dynamic> payload}) async {
    if (!await _isSupported()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final activeActivityId = prefs.getString(_liveActivityIdKey);

    if (activeActivityId == null) {
      final newActivityId = await ActivityKitBridge.startActivity(payload);
      if (newActivityId != null) {
        await prefs.setString(_liveActivityIdKey, newActivityId);
      }
      return;
    }

    final updated = await ActivityKitBridge.updateActivity(
      activityId: activeActivityId,
      payload: payload,
    );

    if (updated) {
      return;
    }

    final replacementActivityId = await ActivityKitBridge.startActivity(payload);
    if (replacementActivityId != null) {
      await prefs.setString(_liveActivityIdKey, replacementActivityId);
    } else {
      await prefs.remove(_liveActivityIdKey);
    }
  }

  Future<bool> _isSupported() async {
    if (!Platform.isIOS) {
      return false;
    }

    if (_activityKitSupported != null) {
      return _activityKitSupported!;
    }

    _activityKitSupported = await ActivityKitBridge.isSupported();
    return _activityKitSupported!;
  }

  Map<String, dynamic> _makePayload({
    required String statusLine,
    required String modeLabel,
    required int changedTaskCount,
    required int totalTaskCount,
    required DateTime updatedAt,
    required double progress,
  }) {
    return <String, dynamic>{
      'title': 'Project Sentinel',
      'statusLine': statusLine,
      'mode': modeLabel,
      'changedTaskCount': changedTaskCount,
      'totalTaskCount': totalTaskCount,
      'updatedAt': updatedAt.toIso8601String(),
      'progress': progress,
    };
  }
}
import 'dart:io';

import 'package:flutter/services.dart';

class ActivityKitBridge {
  ActivityKitBridge._();

  static const MethodChannel _channel = MethodChannel('sentinel/activitykit');

  static Future<bool> isSupported() async {
    if (!Platform.isIOS) {
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> startActivity(Map<String, dynamic> payload) async {
    if (!Platform.isIOS) {
      return null;
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'startActivity',
        payload,
      );
      return result?['activityId'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> updateActivity({
    required String activityId,
    required Map<String, dynamic> payload,
  }) async {
    if (!Platform.isIOS) {
      return false;
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'updateActivity',
        {'activityId': activityId, 'payload': payload},
      );

      return (result?['status'] as String?) == 'updated';
    } catch (_) {
      return false;
    }
  }

  static Future<bool> endActivity(String activityId) async {
    if (!Platform.isIOS) {
      return false;
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'endActivity',
        {'activityId': activityId},
      );

      return (result?['status'] as String?) == 'ended';
    } catch (_) {
      return false;
    }
  }
}

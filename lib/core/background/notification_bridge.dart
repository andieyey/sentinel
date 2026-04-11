import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationBridge.handleTapResponse(response);
}

class NotificationBridge {
  NotificationBridge._();

  static const String channelId = 'sentinel_status_channel';
  static const String channelName = 'Sentinel Status Updates';
  static const String channelDescription =
      'Background heartbeat and scheduler status updates.';
  static const int foregroundNotificationId = 9001;
  static const int eventNotificationId = 9002;
  static const String urgentChannelId = 'sentinel_urgent_channel';
  static const String urgentChannelName = 'Sentinel Urgent Alerts';
  static const String urgentChannelDescription =
      'High-priority schedule risk alerts.';
  static const int urgentNotificationId = 9010;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
    static final StreamController<Map<String, dynamic>> _tapController =
      StreamController<Map<String, dynamic>>.broadcast();
  static bool _isInitialized = false;

    static Stream<Map<String, dynamic>> get onNotificationTap =>
      _tapController.stream;

  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: handleTapResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.low,
      ),
    );

    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        urgentChannelId,
        urgentChannelName,
        description: urgentChannelDescription,
        importance: Importance.max,
      ),
    );

    _isInitialized = true;
  }

  static Future<Map<String, dynamic>?> consumeLaunchTapPayload() async {
    final details = await _notifications.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details?.didNotificationLaunchApp != true || response == null) {
      return null;
    }
    return _parsePayload(response.payload);
  }

  static Future<void> requestPermissions() async {
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();

    final iosImpl = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: false);
  }

  static Future<void> showStatusUpdate({
    required DateTime timestamp,
    required String source,
    int notificationId = eventNotificationId,
    bool ongoing = false,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: ongoing,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _notifications.show(
      notificationId,
      'Sentinel Brain Active',
      'Status Update: ${timestamp.toLocal()} from $source',
      details,
    );
  }

  static Future<void> showTravelRiskAlert({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        urgentChannelId,
        urgentChannelName,
        channelDescription: urgentChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    await _notifications.show(
      urgentNotificationId,
      title,
      body,
      details,
      payload: payload == null ? null : jsonEncode(payload),
    );
  }

  static void handleTapResponse(NotificationResponse response) {
    final payload = _parsePayload(response.payload);
    if (payload == null) {
      return;
    }
    _tapController.add(payload);
  }

  static Map<String, dynamic>? _parsePayload(String? rawPayload) {
    if (rawPayload == null || rawPayload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}

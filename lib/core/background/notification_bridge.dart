import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationBridge {
  NotificationBridge._();

  static const String channelId = 'sentinel_status_channel';
  static const String channelName = 'Sentinel Status Updates';
  static const String channelDescription =
      'Background heartbeat and scheduler status updates.';
  static const int foregroundNotificationId = 9001;
  static const int eventNotificationId = 9002;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _notifications.initialize(initializationSettings);

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

    _isInitialized = true;
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
}

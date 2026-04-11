import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/background/background_status.dart';
import '../core/background/notification_bridge.dart';
import '../core/platform/lock_screen_assistant_controller.dart';
import '../core/scheduler/priority_mode.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/negotiation/presentation/negotiation_screen.dart';
import '../features/scheduler/application/priority_mode_provider.dart';
import 'router/app_navigator.dart';

class SentinelApp extends ConsumerStatefulWidget {
  const SentinelApp({super.key});

  @override
  ConsumerState<SentinelApp> createState() => _SentinelAppState();
}

class _SentinelAppState extends ConsumerState<SentinelApp> {
  StreamSubscription<Map<String, dynamic>>? _notificationTapSubscription;

  @override
  void initState() {
    super.initState();
    _notificationTapSubscription = NotificationBridge.onNotificationTap.listen(
      _openNegotiationFromPayload,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumeLaunchNotificationPayload());
    });
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(backgroundStatusProvider, (_, next) {
      next.whenData((status) {
        if (status.source == 'bootstrap') {
          return;
        }

        final mode = ref.read(priorityModeProvider);
        unawaited(
          LockScreenAssistantController.instance.syncHeartbeat(
            status: status,
            modeLabel: mode.label,
          ),
        );
      });
    });

    return MaterialApp(
      title: 'Project Sentinel',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNavigator.rootNavigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E5A8A)),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute<void>(
            builder: (_) => const SentinelHomeScreen(),
            settings: settings,
          );
        }

        if (settings.name == '/negotiation') {
          final event = settings.arguments as BackgroundRecalculationEvent?;
          return MaterialPageRoute<void>(
            builder: (_) => NegotiationScreen(event: event),
            settings: settings,
          );
        }

        return null;
      },
    );
  }

  Future<void> _consumeLaunchNotificationPayload() async {
    final payload = await NotificationBridge.consumeLaunchTapPayload();
    if (!mounted || payload == null) {
      return;
    }
    _openNegotiationFromPayload(payload);
  }

  void _openNegotiationFromPayload(Map<String, dynamic> payload) {
    final event = BackgroundRecalculationEvent.fromMap(payload);
    AppNavigator.rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/negotiation',
      (route) => route.settings.name != '/negotiation',
      arguments: event,
    );
  }
}

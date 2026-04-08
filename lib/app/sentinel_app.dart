import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/background/background_status.dart';
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
      routes: {
        '/': (_) => const SentinelHomeScreen(),
        '/negotiation': (_) => const NegotiationScreen(),
      },
    );
  }
}

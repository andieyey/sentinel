import 'package:flutter/material.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/negotiation/presentation/negotiation_screen.dart';
import 'router/app_navigator.dart';

class SentinelApp extends StatelessWidget {
  const SentinelApp({super.key});

  @override
  Widget build(BuildContext context) {
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

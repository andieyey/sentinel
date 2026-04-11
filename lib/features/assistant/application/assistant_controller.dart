import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_navigator.dart';
import '../../../core/background/background_status.dart';

final assistantControllerProvider = Provider<AssistantController>((ref) {
  return AssistantController();
});

class AssistantController {
  AssistantController();

  GlobalKey<NavigatorState> get navigatorKey => AppNavigator.rootNavigatorKey;

  void onRecalculationTriggered(BackgroundRecalculationEvent event) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/negotiation',
      (route) => route.settings.name != '/negotiation',
      arguments: event,
    );
  }

  void closeNegotiation() {
    final currentState = navigatorKey.currentState;
    if (currentState != null && currentState.canPop()) {
      currentState.pop();
    }
  }
}

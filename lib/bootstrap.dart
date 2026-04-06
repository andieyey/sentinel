import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/sentinel_app.dart';
import 'core/background/sentinel_background_service.dart';
import 'core/background/workmanager_dispatcher.dart';
import 'core/scheduler/priority_mode.dart';
import 'core/scheduler/priority_mode_persistence.dart';
import 'features/scheduler/domain/conflict_solver.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final persistedMode = await PriorityModePersistence.load();
  ConflictPolicy.isSleepPriority = persistedMode == PriorityMode.sleep;
  await SentinelBackgroundService.initialize();
  await SentinelWorkmanagerDispatcher.initializeAndRegister();
  runApp(const ProviderScope(child: SentinelApp()));
}

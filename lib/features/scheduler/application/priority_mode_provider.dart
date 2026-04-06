import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/scheduler/priority_mode.dart';
import '../../../core/scheduler/priority_mode_persistence.dart';

final priorityModeProvider = StateProvider<PriorityMode>((ref) {
  return PriorityModePersistence.initialMode;
});

final isSleepPriorityProvider = Provider<bool>((ref) {
  return ref.watch(priorityModeProvider) == PriorityMode.sleep;
});

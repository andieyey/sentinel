import 'dart:math';

import '../../tasks/domain/task.dart';

class ConflictPolicy {
  ConflictPolicy._();

  static bool isSleepPriority = true;
  static const int sleepStartHour = 23;
  static const Duration protectedSleepDuration = Duration(hours: 8);
}

List<Task> resolveConflict(List<Task> tasks, DateTime now) {
  final sorted = [...tasks]
    ..sort((a, b) => _priorityWeight(a.priority) - _priorityWeight(b.priority));

  if (ConflictPolicy.isSleepPriority) {
    return _protectSleepBlock(sorted, now);
  }
  return _pushDeadline(sorted, now);
}

List<Task> _protectSleepBlock(List<Task> tasks, DateTime now) {
  var sleepStart = DateTime(
    now.year,
    now.month,
    now.day,
    ConflictPolicy.sleepStartHour,
  );

  if (now.isAfter(sleepStart)) {
    sleepStart = sleepStart.add(const Duration(days: 1));
  }

  final sleepEnd = sleepStart.add(ConflictPolicy.protectedSleepDuration);
  final tomorrowStart = DateTime(
    sleepStart.year,
    sleepStart.month,
    sleepStart.day,
    9,
  ).add(const Duration(days: 1));

  for (final task in tasks) {
    final intersectsSleep =
        task.scheduledStart.isBefore(sleepEnd) &&
        task.scheduledEnd.isAfter(sleepStart);

    if (!intersectsSleep ||
        task.isPinned ||
        task.isInelastic ||
        !task.isElastic) {
      continue;
    }

    final duration = task.scheduledEnd.difference(task.scheduledStart);
    task.scheduledStart = tomorrowStart;
    task.scheduledEnd = tomorrowStart.add(duration);
    task.deferredTo = tomorrowStart;
    task.status = TaskStatus.deferred;
  }

  return tasks;
}

List<Task> _pushDeadline(List<Task> tasks, DateTime now) {
  for (final task in tasks) {
    if (task.isInelastic || task.isPinned) {
      continue;
    }

    if (task.bufferMinutes > 0) {
      task.bufferMinutes = max(5, (task.bufferMinutes / 2).round());
    }

    if (task.status == TaskStatus.deferred && task.deferredTo != null) {
      final shiftedStart = task.deferredTo!.subtract(const Duration(hours: 2));
      final clampedStart = shiftedStart.isBefore(now) ? now : shiftedStart;
      final duration = task.scheduledEnd.difference(task.scheduledStart);
      task.scheduledStart = clampedStart;
      task.scheduledEnd = clampedStart.add(duration);
      task.deferredTo = null;
      task.status = TaskStatus.pending;
    }
  }

  return tasks;
}

int _priorityWeight(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.low:
      return 0;
    case TaskPriority.medium:
      return 1;
    case TaskPriority.high:
      return 2;
    case TaskPriority.critical:
      return 3;
  }
}

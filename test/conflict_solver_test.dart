import 'package:flutter_test/flutter_test.dart';

import 'package:sentinel/features/scheduler/domain/conflict_solver.dart';
import 'package:sentinel/features/tasks/domain/task.dart';

Task _task({
  required DateTime start,
  required DateTime end,
  TaskPriority priority = TaskPriority.medium,
  bool isElastic = true,
  bool isInelastic = false,
  bool isPinned = false,
  int bufferMinutes = 15,
  TaskStatus status = TaskStatus.pending,
  DateTime? deferredTo,
}) {
  final task = Task()
    ..title = 'Test task'
    ..scheduledStart = start
    ..scheduledEnd = end
    ..priority = priority
    ..isElastic = isElastic
    ..isInelastic = isInelastic
    ..isPinned = isPinned
    ..bufferMinutes = bufferMinutes
    ..status = status
    ..deferredTo = deferredTo;

  return task;
}

void main() {
  group('resolveConflict', () {
    test('sleep priority defers elastic tasks that overlap sleep block', () {
      ConflictPolicy.isSleepPriority = true;
      final now = DateTime(2026, 4, 9, 20, 0);
      final overlappingTask = _task(
        start: DateTime(2026, 4, 9, 23, 30),
        end: DateTime(2026, 4, 10, 0, 30),
      );

      final result = resolveConflict([overlappingTask], now).single;

      final expectedStart = DateTime(2026, 4, 10, 9, 0);
      expect(result.status, TaskStatus.deferred);
      expect(result.deferredTo, expectedStart);
      expect(result.scheduledStart, expectedStart);
      expect(result.scheduledEnd, expectedStart.add(const Duration(hours: 1)));
    });

    test('sleep priority keeps pinned and inelastic tasks untouched', () {
      ConflictPolicy.isSleepPriority = true;
      final now = DateTime(2026, 4, 9, 20, 0);
      final pinned = _task(
        start: DateTime(2026, 4, 9, 23, 30),
        end: DateTime(2026, 4, 10, 0, 30),
        isPinned: true,
      );
      final inelastic = _task(
        start: DateTime(2026, 4, 9, 23, 45),
        end: DateTime(2026, 4, 10, 0, 45),
        isElastic: false,
        isInelastic: true,
      );

      final result = resolveConflict([pinned, inelastic], now);

      expect(result[0].status, TaskStatus.pending);
      expect(result[0].deferredTo, isNull);
      expect(result[0].scheduledStart, DateTime(2026, 4, 9, 23, 30));

      expect(result[1].status, TaskStatus.pending);
      expect(result[1].deferredTo, isNull);
      expect(result[1].scheduledStart, DateTime(2026, 4, 9, 23, 45));
    });

    test('deadline priority compresses buffer and pulls deferred tasks forward', () {
      ConflictPolicy.isSleepPriority = false;
      final now = DateTime(2026, 4, 9, 10, 0);
      final deferredTask = _task(
        start: DateTime(2026, 4, 10, 14, 0),
        end: DateTime(2026, 4, 10, 15, 0),
        bufferMinutes: 12,
        status: TaskStatus.deferred,
        deferredTo: DateTime(2026, 4, 10, 14, 0),
      );
      final nearNowDeferred = _task(
        start: DateTime(2026, 4, 9, 12, 0),
        end: DateTime(2026, 4, 9, 13, 0),
        bufferMinutes: 8,
        status: TaskStatus.deferred,
        deferredTo: DateTime(2026, 4, 9, 11, 0),
      );

      final result = resolveConflict([deferredTask, nearNowDeferred], now);

      expect(result[0].bufferMinutes, 6);
      expect(result[0].status, TaskStatus.pending);
      expect(result[0].deferredTo, isNull);
      expect(result[0].scheduledStart, DateTime(2026, 4, 10, 12, 0));
      expect(result[0].scheduledEnd, DateTime(2026, 4, 10, 13, 0));

      expect(result[1].bufferMinutes, 5);
      expect(result[1].scheduledStart, now);
      expect(result[1].scheduledEnd, now.add(const Duration(hours: 1)));
    });
  });
}

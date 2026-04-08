import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/scheduler/domain/conflict_solver.dart';
import '../../features/tasks/domain/task.dart';

class SchedulerRecalculationResult {
  const SchedulerRecalculationResult({
    required this.changedTaskCount,
    required this.totalTaskCount,
    required this.triggerSource,
    this.error,
  });

  final int changedTaskCount;
  final int totalTaskCount;
  final String triggerSource;
  final Object? error;

  bool get didChangeSchedule => changedTaskCount > 0;
  bool get hasError => error != null;
}

class BackgroundSchedulerOrchestrator {
  static const String _isarName = 'sentinel_local';

  Isar? _isar;
  bool _isRecalculating = false;

  Future<void> initialize() async {
    await _ensureIsar();
  }

  Future<bool> hasInProgressTravelTask() async {
    final isar = await _ensureIsar();
    final tasks = await isar.tasks.where().findAll();

    return tasks.any((task) {
      if (task.status != TaskStatus.inProgress) {
        return false;
      }

      final title = task.title.toLowerCase();
      final description = task.description?.toLowerCase() ?? '';
      return title.contains('travel') || description.contains('travel');
    });
  }

  Future<SchedulerRecalculationResult> recalculate({
    required DateTime now,
    required String triggerSource,
    double? latitude,
    double? longitude,
  }) async {
    if (_isRecalculating) {
      return SchedulerRecalculationResult(
        changedTaskCount: 0,
        totalTaskCount: 0,
        triggerSource: '$triggerSource(skipped_busy)',
      );
    }

    _isRecalculating = true;

    try {
      final isar = await _ensureIsar();
      final allTasks = await isar.tasks.where().findAll();
      final activeTasks = allTasks
          .where((task) => task.status != TaskStatus.completed)
          .toList();

      if (activeTasks.isEmpty) {
        return SchedulerRecalculationResult(
          changedTaskCount: 0,
          totalTaskCount: 0,
          triggerSource: triggerSource,
        );
      }

      final snapshots = {
        for (final task in activeTasks) task.id: _TaskSnapshot.fromTask(task),
      };

      final resolvedTasks = resolveConflict(activeTasks, now);
      if (latitude != null && longitude != null) {
        for (final task in resolvedTasks) {
          if (task.status == TaskStatus.inProgress ||
              task.status == TaskStatus.pending) {
            task.latitude = latitude;
            task.longitude = longitude;
          }
        }
      }

      var changedTaskCount = 0;
      for (final task in resolvedTasks) {
        final previous = snapshots[task.id];
        task.updatedAt = now;
        if (previous == null || previous.hasChanged(task)) {
          changedTaskCount++;
        }
      }

      if (changedTaskCount > 0) {
        await isar.writeTxn(() async {
          await isar.tasks.putAll(resolvedTasks);
        });
      }

      return SchedulerRecalculationResult(
        changedTaskCount: changedTaskCount,
        totalTaskCount: resolvedTasks.length,
        triggerSource: triggerSource,
      );
    } catch (error) {
      return SchedulerRecalculationResult(
        changedTaskCount: 0,
        totalTaskCount: 0,
        triggerSource: triggerSource,
        error: error,
      );
    } finally {
      _isRecalculating = false;
    }
  }

  Future<void> dispose() async {
    if (_isar != null && _isar!.isOpen) {
      await _isar!.close();
    }
    _isar = null;
  }

  Future<Isar> _ensureIsar() async {
    if (_isar != null && _isar!.isOpen) {
      return _isar!;
    }

    final existing = Isar.getInstance(_isarName);
    if (existing != null) {
      _isar = existing;
      return existing;
    }

    final appDir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [TaskSchema],
      directory: appDir.path,
      name: _isarName,
    );

    return _isar!;
  }
}

class _TaskSnapshot {
  const _TaskSnapshot({
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.bufferMinutes,
    required this.status,
    required this.deferredTo,
    required this.latitude,
    required this.longitude,
  });

  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final int bufferMinutes;
  final TaskStatus status;
  final DateTime? deferredTo;
  final double? latitude;
  final double? longitude;

  factory _TaskSnapshot.fromTask(Task task) {
    return _TaskSnapshot(
      scheduledStart: task.scheduledStart,
      scheduledEnd: task.scheduledEnd,
      bufferMinutes: task.bufferMinutes,
      status: task.status,
      deferredTo: task.deferredTo,
      latitude: task.latitude,
      longitude: task.longitude,
    );
  }

  bool hasChanged(Task task) {
    return scheduledStart != task.scheduledStart ||
        scheduledEnd != task.scheduledEnd ||
        bufferMinutes != task.bufferMinutes ||
        status != task.status ||
        deferredTo != task.deferredTo ||
        latitude != task.latitude ||
        longitude != task.longitude;
  }
}

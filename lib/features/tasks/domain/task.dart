import 'package:isar/isar.dart';

part 'task.g.dart';

enum TaskPriority { low, medium, high, critical }

enum TaskStatus { pending, inProgress, deferred, completed }

@collection
class Task {
  Id id = Isar.autoIncrement;

  late String title;
  String? description;

  @enumerated
  TaskPriority priority = TaskPriority.medium;

  @enumerated
  TaskStatus status = TaskStatus.pending;

  late DateTime scheduledStart;
  late DateTime scheduledEnd;

  int bufferMinutes = 15;

  bool isElastic = true;
  bool isInelastic = false;
  bool isPinned = false;

  DateTime? deferredTo;

  double? latitude;
  double? longitude;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}

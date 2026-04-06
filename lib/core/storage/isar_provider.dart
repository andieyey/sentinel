import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/tasks/domain/task.dart';

final isarProvider = FutureProvider<Isar>((ref) async {
  final appDir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [TaskSchema],
    directory: appDir.path,
    name: 'sentinel_local',
  );

  ref.onDispose(() {
    if (isar.isOpen) {
      isar.close();
    }
  });

  return isar;
});

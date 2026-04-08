import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/background/background_status.dart';
import '../../../core/platform/lock_screen_assistant_controller.dart';
import '../../../core/scheduler/priority_mode.dart';
import '../../../core/scheduler/priority_mode_persistence.dart';
import '../../../core/storage/isar_provider.dart';
import '../../../shared/spotlight/spotlight_overlay.dart';
import '../../assistant/application/assistant_controller.dart';
import '../../scheduler/application/priority_mode_provider.dart';
import '../../scheduler/domain/conflict_solver.dart';

class SentinelHomeScreen extends ConsumerStatefulWidget {
  const SentinelHomeScreen({super.key});

  @override
  ConsumerState<SentinelHomeScreen> createState() => _SentinelHomeScreenState();
}

class _SentinelHomeScreenState extends ConsumerState<SentinelHomeScreen> {
  final GlobalKey _priorityToggleKey = GlobalKey();

  void _showSpotlight() {
    final targetContext = _priorityToggleKey.currentContext;
    if (targetContext == null) {
      return;
    }

    final renderBox = targetContext.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }

    final rect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    ref
        .read(spotlightOverlayControllerProvider)
        .show(context, spotlightRect: rect.inflate(10));
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(priorityModeProvider);
    final backgroundStatus = ref.watch(backgroundStatusProvider);
    final recalculationStatus = ref.watch(backgroundRecalculationProvider);
    final gpsTick = ref.watch(backgroundGpsTickProvider);
    final gpsStatus = ref.watch(backgroundGpsStatusProvider);
    final isarState = ref.watch(isarProvider);

    ref.listen(backgroundRecalculationProvider, (_, next) {
      next.whenData((event) {
        if (!event.isThrottled && event.changedTaskCount > 0) {
          final mode = ref.read(priorityModeProvider);
          unawaited(
            LockScreenAssistantController.instance.syncRecalculation(
              event: event,
              mode: mode,
            ),
          );
          ref.read(assistantControllerProvider).onRecalculationTriggered();
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Project Sentinel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Adaptive Task Scheduler',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mode: ${mode.label}'),
                    const SizedBox(height: 8),
                    SegmentedButton<PriorityMode>(
                      key: _priorityToggleKey,
                      segments: const [
                        ButtonSegment(
                          value: PriorityMode.sleep,
                          label: Text('Sleep'),
                        ),
                        ButtonSegment(
                          value: PriorityMode.deadline,
                          label: Text('Deadline'),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (selection) {
                        final selected = selection.first;
                        ref.read(priorityModeProvider.notifier).state =
                            selected;
                        ConflictPolicy.isSleepPriority =
                            selected.isSleepPriority;
                        unawaited(PriorityModePersistence.save(selected));
                        FlutterBackgroundService().invoke(
                          'priority_mode_update',
                          {'isSleepPriority': selected.isSleepPriority},
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Isar Status'),
                subtitle: Text(
                  isarState.when(
                    data: (_) => 'Connected to local-first storage',
                    loading: () => 'Opening database...',
                    error: (error, _) => 'Error: $error',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Background Heartbeat'),
                subtitle: backgroundStatus.when(
                  data: (status) => Text(
                    'Last update: ${status.timestamp.toLocal()} (${status.source})',
                  ),
                  loading: () =>
                      const Text('Waiting for background isolate...'),
                  error: (error, _) => Text('Error: $error'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Recalculation Feed'),
                subtitle: recalculationStatus.when(
                  data: (event) {
                    if (event.isThrottled) {
                      return Text(
                        'Throttled ${event.triggerSource} (${event.throttleKey}) for ${event.minimumIntervalMs}ms',
                      );
                    }
                    return Text(
                      'Changed ${event.changedTaskCount}/${event.totalTaskCount} tasks from ${event.triggerSource}',
                    );
                  },
                  loading: () =>
                      const Text('Waiting for recalculation events...'),
                  error: (error, _) => Text('Error: $error'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('GPS Stream'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    gpsStatus.when(
                      data: (status) => Text(
                        'Status: ${status.state}${status.permission == null ? '' : ' (${status.permission})'}',
                      ),
                      loading: () => const Text('Status: waiting...'),
                      error: (error, _) => Text('Status error: $error'),
                    ),
                    const SizedBox(height: 4),
                    gpsTick.when(
                      data: (tick) => Text(
                        'Last tick: ${tick.latitude.toStringAsFixed(5)}, ${tick.longitude.toStringAsFixed(5)} (${tick.source}, ${tick.timestamp.toLocal()})',
                      ),
                      loading: () => const Text('Last tick: waiting...'),
                      error: (error, _) => Text('Tick error: $error'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _showSpotlight,
                  child: const Text('Start Spotlight'),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    ref.read(spotlightOverlayControllerProvider).hide();
                  },
                  child: const Text('Clear Spotlight'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

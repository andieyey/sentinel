# Project Sentinel

Adaptive task scheduler that treats time as a liquid resource.

## Stack

- Flutter (mobile)
- Riverpod (global state)
- Isar (local-first storage)
- flutter_background_service + workmanager (background orchestration)
- Local notifications as external system status surface

## Implemented in this milestone

- Background Brain isolate bootstrapped with flutter_background_service
- 10-minute status heartbeat notifications
- Time and GPS signal stream hooks emitted from the background isolate
- Isar-backed background recalculation loop that persists conflict resolution updates
- Isar Task schema with isInelastic and isPinned flags
- Conflict solver entry point:
	- resolveConflict(List<Task> tasks, DateTime now)
	- sleep priority path protects an 8-hour sleep block by deferring low-priority elastic work
	- deadline priority path compresses buffers and pulls deferred tasks forward
- Global navigator key and assistant controller for proactive route transitions
- Recalculation event feed wired to proactive navigation trigger
- Spotlight overlay system with OverlayEntry + CustomClipper hole punch
- Persisted global priority mode that restores on startup and background service boot
- Debounced and throttled recalculation policy for noisy GPS/time streams
- Real iOS ActivityKit lifecycle bridge (start/update/end) over method channel

## Quick start

1. Install dependencies.

```bash
flutter pub get
```

2. Generate Isar schema files.

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

3. Run on device/emulator.

```bash
flutter run
```

## Structure

```text
lib/
	app/
		router/app_navigator.dart
		sentinel_app.dart
	core/
		background/
			background_status.dart
			notification_bridge.dart
			sentinel_background_service.dart
			workmanager_dispatcher.dart
		scheduler/priority_mode.dart
		storage/isar_provider.dart
	features/
		assistant/application/assistant_controller.dart
		home/presentation/home_screen.dart
		negotiation/presentation/negotiation_screen.dart
		scheduler/
			application/priority_mode_provider.dart
			domain/conflict_solver.dart
		tasks/domain/task.dart
	shared/spotlight/spotlight_overlay.dart
	bootstrap.dart
	main.dart
```

## Platform notes

- Android manifest includes foreground service, boot receiver, notifications, and location permissions.
- iOS Info.plist includes background modes and location usage descriptions.
- Workmanager periodic cadence on Android is 15 minutes minimum; the foreground service timer drives the required 10-minute status update cadence.

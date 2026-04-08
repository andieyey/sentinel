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
- Heartbeat events now sync to an iOS Live Activity, while Android keeps the persistent foreground notification updated

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

## PoC validation checklist

1. Verify automated checks.

```bash
flutter test
flutter test test/conflict_solver_test.dart
```

2. Verify scheduler behavior in-app.

- In Sleep mode, ensure an elastic task overlapping the sleep window is deferred.
- In Deadline mode, ensure deferred tasks are pulled forward and buffers are reduced.

3. Verify runtime PoC signals on the home screen.

- Background Heartbeat updates roughly every 10 minutes.
- Recalculation Feed updates after recalculation triggers.
- GPS Stream shows permission/status and tick updates when available.

4. Verify assistant/overlay hooks.

- Tap Simulate Recalculation and confirm proactive assistant flow is triggered.
- Tap Start Spotlight and verify the priority mode control is highlighted.

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

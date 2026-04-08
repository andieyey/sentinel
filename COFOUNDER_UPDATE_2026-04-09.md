# Cofounder Update - 2026-04-09

## What changed

1. Replaced manual recalculation trigger in the home UI.
- Removed the "Simulate Recalculation" button.
- Recalculation is now driven by real runtime events from GPS behavior.

2. Added real stationary-travel trigger logic in background service.
- While an in-progress Travel task exists, GPS ticks are monitored.
- If user movement stays within ~25m for 5 minutes, background recalculation is triggered.
- Trigger source emitted: `gps_travel_stationary_5m`.

3. Added Travel task detection in scheduler orchestrator.
- New check for active in-progress tasks with "travel" in title or description.
- This gates the new stationary trigger to travel-specific contexts.

4. Piped heartbeat into the lock screen.
- iOS heartbeat events now sync to a Live Activity.
- Android already uses the persistent foreground notification, and the heartbeat keeps that updated.
- Live Activity updates are centralized so recalculation events and heartbeat events share the same lock-screen surface.

5. Refined obstacle / stationary detection.
- Replaced the simple GPS distance check with a reusable stationary detector.
- The detector now ignores normal driving motion, requires a short warmup, and only triggers after a sustained stop.
- This reduces false positives from short stops like red lights while still catching true Travel interruptions.

## Files changed

- `lib/features/home/presentation/home_screen.dart`
- `lib/core/background/sentinel_background_service.dart`
- `lib/core/scheduler/background_scheduler_orchestrator.dart`
- `lib/app/sentinel_app.dart`
- `lib/core/platform/lock_screen_assistant_controller.dart`
- `lib/core/background/travel_stationary_detector.dart`
- `test/travel_stationary_detector_test.dart`

## Validation performed

- `flutter test` passed.
- `flutter analyze` passed with no issues.
- Android emulator launch succeeded with latest changes.
- The new stationary detector tests passed as part of the suite.

## Notes and known caveats

- Web build is still not configured for this project.
- Android logs still show foreground-location service permission warnings on newer Android behavior; app boots, but background location permissions/policy should be hardened in a follow-up.

## Why this matters for product

- The assistant/recalculation flow now reacts to real user context (stationary during travel) instead of a manual dev button.
- The obstacle detection is now more deliberate, so the app is less likely to treat brief traffic stops as a genuine Travel stall.
- This moves the PoC from demo interaction toward behavior-driven automation.

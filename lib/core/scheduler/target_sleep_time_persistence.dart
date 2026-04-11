import 'package:shared_preferences/shared_preferences.dart';

class TargetSleepTime {
  const TargetSleepTime({required this.hour, required this.minute});

  final int hour;
  final int minute;

  String toStorageValue() {
    final hourText = hour.toString().padLeft(2, '0');
    final minuteText = minute.toString().padLeft(2, '0');
    return '$hourText:$minuteText';
  }

  static TargetSleepTime? tryParse(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    final parts = rawValue.split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    return TargetSleepTime(hour: hour, minute: minute);
  }
}

class TargetSleepTimePersistence {
  TargetSleepTimePersistence._();

  static const String _key = 'sentinel.target_sleep_time';
  static const TargetSleepTime _defaultValue =
      TargetSleepTime(hour: 23, minute: 0);

  static Future<TargetSleepTime> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_key);
    return TargetSleepTime.tryParse(rawValue) ?? _defaultValue;
  }

  static Future<void> save(TargetSleepTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.toStorageValue());
  }
}

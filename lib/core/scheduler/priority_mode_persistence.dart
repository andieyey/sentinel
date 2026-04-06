import 'package:shared_preferences/shared_preferences.dart';

import 'priority_mode.dart';

class PriorityModePersistence {
  PriorityModePersistence._();

  static const String _storageKey = 'sentinel.priority_mode';
  static PriorityMode initialMode = PriorityMode.sleep;

  static Future<PriorityMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final mode = parsePriorityMode(raw);
    initialMode = mode;
    return mode;
  }

  static Future<void> save(PriorityMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, mode.name);
    initialMode = mode;
  }
}

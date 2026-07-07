import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/lecture.dart';

/// Offline cache for a cohort's schedule — a JSON snapshot per cohort in
/// shared_preferences. Enough to render the last-known schedule offline (the
/// DPA/UX "cached schedule readable offline" requirement); writes always require
/// connectivity. Keyed by cohort so switching accounts never leaks a schedule.
class ScheduleCache {
  const ScheduleCache();

  static const _prefix = 'schedule_cache_';

  Future<void> save(String cohortId, List<Lecture> events) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(events.map((e) => e.toCacheJson()).toList());
    await prefs.setString('$_prefix$cohortId', json);
  }

  /// The cached schedule for [cohortId], or an empty list if nothing is cached
  /// or the stored blob is unreadable (treated as a cache miss, never a crash).
  Future<List<Lecture>> load(String cohortId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$cohortId');
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Lecture.fromMap((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

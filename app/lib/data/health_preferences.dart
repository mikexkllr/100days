import 'package:hundred_core/hundred_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which habits the user allowed the watch to fill in, and when it last ran.
///
/// Device-local on purpose. Nothing here belongs in the signed feed: whether
/// this phone reads Health Connect is a property of the phone, not of the
/// challenge, and a friend has no business knowing it. The *result* of an
/// import is a normal check-in and does go into the feed — labelled, so the
/// distinction stays visible.
class HealthPreferences {
  const HealthPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const String _enabledKey = 'health_categories_v1';
  static const String _autoKey = 'health_auto_import_v1';
  static const String _lastRunKey = 'health_last_import_v1';

  static Future<HealthPreferences> open() async =>
      HealthPreferences(await SharedPreferences.getInstance());

  /// Empty by default. Nothing is read until the user picks a habit — an app
  /// that starts pulling health data because it was installed is exactly the
  /// behaviour this project exists to avoid.
  Set<HabitCategory> enabledCategories() {
    final List<String>? stored = _prefs.getStringList(_enabledKey);
    if (stored == null) return const <HabitCategory>{};
    return stored
        .map((String name) => HabitCategory.values
            .where((HabitCategory c) => c.name == name)
            .firstOrNull)
        .nonNulls
        .where(healthLinkableCategories.contains)
        .toSet();
  }

  Future<void> setEnabledCategories(Set<HabitCategory> categories) =>
      _prefs.setStringList(
        _enabledKey,
        categories.map((HabitCategory c) => c.name).toList(growable: false),
      );

  /// Whether an import may run without the user pressing anything. On by
  /// default *once a habit is enabled* — enabling a habit is the consent.
  bool autoImport() => _prefs.getBool(_autoKey) ?? true;

  Future<void> setAutoImport(bool value) => _prefs.setBool(_autoKey, value);

  DateTime? lastImportAt() {
    final int? millis = _prefs.getInt(_lastRunKey);
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLastImportAt(DateTime when) =>
      _prefs.setInt(_lastRunKey, when.millisecondsSinceEpoch);

  Future<void> clear() async {
    await _prefs.remove(_enabledKey);
    await _prefs.remove(_autoKey);
    await _prefs.remove(_lastRunKey);
  }
}

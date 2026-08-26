import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// The languages the app ships.
const List<Locale> kSupportedLocales = <Locale>[
  Locale('de'),
  Locale('en'),
];

/// Remembers an explicit language choice.
///
/// Null means "follow the system", which is the default and what most people
/// want; the override exists for the fair number of people whose phone is in
/// one language and whose head is in another.
class LocaleStore {
  const LocaleStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'app_locale_v1';

  static Future<LocaleStore> open() async =>
      LocaleStore(await SharedPreferences.getInstance());

  Locale? read() {
    final code = _prefs.getString(_key);
    if (code == null) return null;
    final match = kSupportedLocales
        .where((Locale l) => l.languageCode == code)
        .firstOrNull;
    return match;
  }

  Future<void> write(Locale? locale) async {
    if (locale == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, locale.languageCode);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Choices that belong to this phone rather than to the account: when to be
/// reminded, whether the app may make sounds, how a habit is checked in.
@immutable
class AppPrefs {
  const AppPrefs({
    this.remindersOn = true,
    this.reminderTime = const TimeOfDay(hour: 18, minute: 30),
    this.streakWarningOn = true,
    this.permissionAsked = false,
    this.soundOn = true,
    this.tapToCheckIn = false,
    this.lossShownFor,
  });

  /// The daily "today is still open" reminder.
  final bool remindersOn;
  final TimeOfDay reminderTime;

  /// The evening warning when the streak is on the line.
  final bool streakWarningOn;

  /// Whether the app has asked for notification permission yet — it asks
  /// once, with an explanation, not as a bare system dialog.
  final bool permissionAsked;

  /// Crackle, ignition and the slot machine. Follows the silent switch.
  final bool soundOn;

  /// A plain tap checks a habit in, for people who cannot hold a press.
  final bool tapToCheckIn;

  /// The day whose lost streak Funki already talked about, so the morning
  /// after is said once.
  final String? lossShownFor;

  AppPrefs copyWith({
    bool? remindersOn,
    TimeOfDay? reminderTime,
    bool? streakWarningOn,
    bool? permissionAsked,
    bool? soundOn,
    bool? tapToCheckIn,
    String? lossShownFor,
  }) =>
      AppPrefs(
        remindersOn: remindersOn ?? this.remindersOn,
        reminderTime: reminderTime ?? this.reminderTime,
        streakWarningOn: streakWarningOn ?? this.streakWarningOn,
        permissionAsked: permissionAsked ?? this.permissionAsked,
        soundOn: soundOn ?? this.soundOn,
        tapToCheckIn: tapToCheckIn ?? this.tapToCheckIn,
        lossShownFor: lossShownFor ?? this.lossShownFor,
      );

  Map<String, Object> toMap() => <String, Object>{
        'reminders': remindersOn,
        'reminderMinute': reminderTime.hour * 60 + reminderTime.minute,
        'streakWarning': streakWarningOn,
        'permissionAsked': permissionAsked,
        'sound': soundOn,
        'tapToCheckIn': tapToCheckIn,
        if (lossShownFor != null) 'lossShownFor': lossShownFor!,
      };

  static AppPrefs fromMap(Map<String, Object?> map) {
    final int minute = (map['reminderMinute'] as int?) ?? 18 * 60 + 30;
    return AppPrefs(
      remindersOn: (map['reminders'] as bool?) ?? true,
      reminderTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      streakWarningOn: (map['streakWarning'] as bool?) ?? true,
      permissionAsked: (map['permissionAsked'] as bool?) ?? false,
      soundOn: (map['sound'] as bool?) ?? true,
      tapToCheckIn: (map['tapToCheckIn'] as bool?) ?? false,
      lossShownFor: map['lossShownFor'] as String?,
    );
  }
}

/// Where [AppPrefs] live. The app uses [SharedPrefsStore]; tests and the
/// demo keep them in memory.
abstract class AppPrefsStore {
  AppPrefs read();
  Future<void> write(AppPrefs prefs);
}

class MemoryPrefsStore implements AppPrefsStore {
  MemoryPrefsStore([this._prefs = const AppPrefs()]);

  AppPrefs _prefs;

  @override
  AppPrefs read() => _prefs;

  @override
  Future<void> write(AppPrefs prefs) async => _prefs = prefs;
}

class SharedPrefsStore implements AppPrefsStore {
  SharedPrefsStore(this._prefs);

  final SharedPreferences _prefs;
  static const String _prefix = 'prefs_v1.';

  static Future<SharedPrefsStore> open() async =>
      SharedPrefsStore(await SharedPreferences.getInstance());

  @override
  AppPrefs read() => AppPrefs.fromMap(<String, Object?>{
        for (final String key in _prefs.getKeys())
          if (key.startsWith(_prefix)) key.substring(_prefix.length): _prefs.get(key),
      });

  @override
  Future<void> write(AppPrefs prefs) async {
    for (final MapEntry<String, Object> entry in prefs.toMap().entries) {
      final String key = '$_prefix${entry.key}';
      final Object value = entry.value;
      if (value is bool) await _prefs.setBool(key, value);
      if (value is int) await _prefs.setInt(key, value);
      if (value is String) await _prefs.setString(key, value);
    }
  }
}

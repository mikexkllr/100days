import 'package:meta/meta.dart';

import '../util/dates.dart';

/// When a household goes shopping. A list covers the days from one trip to
/// the next, so the plan for those days is what goes on it.
sealed class ShoppingCadence {
  const ShoppingCadence();

  factory ShoppingCadence.fromJson(Map<String, dynamic> json) {
    switch (json['kind']) {
      case 'everyNDays':
        return EveryNDays(
          days: ((json['days'] as num?)?.toInt() ?? 7).clamp(1, 31),
          anchor: DayKey.parse(json['anchor'] as String? ?? DayKey.today().toString()),
        );
      case 'manual':
        return ManualShopping(
          days: ((json['days'] as num?)?.toInt() ?? 7).clamp(1, 31),
        );
      default:
        return WeeklyShopping(
          weekday: ((json['weekday'] as num?)?.toInt() ?? DateTime.saturday).clamp(1, 7),
        );
    }
  }

  Map<String, dynamic> toJson();

  /// The next shopping day on or after [from], or null without a fixed
  /// rhythm.
  DayKey? nextTrip(DayKey from);

  /// The days a list made on [day] is for: from [day] up to the day before
  /// the next trip after it.
  ShoppingPeriod periodFrom(DayKey day);
}

/// Every week on the same day — the default, Saturday.
@immutable
class WeeklyShopping extends ShoppingCadence {
  const WeeklyShopping({this.weekday = DateTime.saturday});

  /// [DateTime.monday] … [DateTime.sunday].
  final int weekday;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'kind': 'weekly', 'weekday': weekday};

  @override
  DayKey nextTrip(DayKey from) {
    final delta = (weekday - from.toDateTime().weekday + 7) % 7;
    return from.addDays(delta);
  }

  @override
  ShoppingPeriod periodFrom(DayKey day) {
    final after = nextTrip(day.addDays(1));
    return ShoppingPeriod(day, after.addDays(-1));
  }
}

/// Every [days] days, counted from [anchor] — for a fortnightly big shop, or
/// a household that goes twice a week (`days: 3` or `4`).
@immutable
class EveryNDays extends ShoppingCadence {
  const EveryNDays({required this.days, required this.anchor});

  final int days;
  final DayKey anchor;

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'kind': 'everyNDays', 'days': days, 'anchor': anchor.toString()};

  @override
  DayKey nextTrip(DayKey from) {
    final since = from.differenceInDays(anchor);
    if (since <= 0) return anchor;
    final remainder = since % days;
    return remainder == 0 ? from : from.addDays(days - remainder);
  }

  @override
  ShoppingPeriod periodFrom(DayKey day) {
    final after = nextTrip(day.addDays(1));
    return ShoppingPeriod(day, after.addDays(-1));
  }
}

/// No rhythm: a list whenever someone makes one, covering the next [days].
@immutable
class ManualShopping extends ShoppingCadence {
  const ManualShopping({this.days = 7});

  final int days;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'kind': 'manual', 'days': days};

  @override
  DayKey? nextTrip(DayKey from) => null;

  @override
  ShoppingPeriod periodFrom(DayKey day) => ShoppingPeriod(day, day.addDays(days - 1));
}

/// A closed range of days.
@immutable
class ShoppingPeriod {
  const ShoppingPeriod(this.start, this.end);

  final DayKey start;
  final DayKey end;

  int get lengthDays => end.differenceInDays(start) + 1;

  bool contains(DayKey day) => !day.isBefore(start) && !day.isAfter(end);

  @override
  bool operator ==(Object other) => other is ShoppingPeriod && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start…$end';
}

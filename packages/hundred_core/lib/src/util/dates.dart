/// Everything in the app is keyed by *local* calendar day, not by instant: a
/// check-in at 23:59 and one at 00:01 are different days even though they are
/// two minutes apart, and that is exactly what a streak means to a user.
class DayKey implements Comparable<DayKey> {
  const DayKey(this.year, this.month, this.day);

  factory DayKey.fromDateTime(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    return DayKey(local.year, local.month, local.day);
  }

  factory DayKey.parse(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) {
      throw FormatException('Expected yyyy-MM-dd', iso);
    }
    return DayKey(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  final int year;
  final int month;
  final int day;

  static DayKey today() => DayKey.fromDateTime(DateTime.now());

  DateTime toDateTime() => DateTime(year, month, day);

  DayKey addDays(int days) =>
      DayKey.fromDateTime(DateTime(year, month, day + days));

  int differenceInDays(DayKey other) =>
      toDateTime().difference(other.toDateTime()).inDays;

  bool isAfter(DayKey other) => compareTo(other) > 0;

  bool isBefore(DayKey other) => compareTo(other) < 0;

  /// ISO-8601 week key (`2026-W12`), the bucket the weekly league scores over.
  String get isoWeekKey {
    final date = toDateTime();
    final thursday = date.add(Duration(days: 4 - (date.weekday)));
    final firstJan = DateTime(thursday.year, 1, 1);
    final week = ((thursday.difference(firstJan).inDays) / 7).floor() + 1;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  @override
  int compareTo(DayKey other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  String toString() => '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is DayKey &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

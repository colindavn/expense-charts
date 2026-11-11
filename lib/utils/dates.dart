/// Calendar-day helpers that are safe across daylight-saving changes.
class Dates {
  Dates._();

  /// Current time. Tests and screenshots can replace it.
  static DateTime Function() now = DateTime.now;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Whole calendar days from [a] to [b] (negative if b is before a).
  static int daysBetween(DateTime a, DateTime b) {
    final ua = DateTime.utc(a.year, a.month, a.day);
    final ub = DateTime.utc(b.year, b.month, b.day);
    return ub.difference(ua).inDays;
  }

  static DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  static DateTime monthStart(DateTime d) => DateTime(d.year, d.month, 1);
  static DateTime monthEnd(DateTime d) => DateTime(d.year, d.month, daysInMonth(d.year, d.month));

  /// First day of the week containing [d]. [weekStartsOn] uses DateTime.monday..sunday.
  static DateTime weekStart(DateTime d, int weekStartsOn) {
    final offset = (d.weekday - weekStartsOn + 7) % 7;
    return addDays(dateOnly(d), -offset);
  }

  /// Entries are stored at noon local time so day boundaries never shift.
  static DateTime atNoon(DateTime d) => DateTime(d.year, d.month, d.day, 12);
}

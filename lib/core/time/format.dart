/// Date/time helpers for organization-local display without a timezone
/// database. Indonesian zones have fixed offsets (no daylight saving).
abstract final class Clock {
  static const _offsets = {
    'Asia/Jakarta': 7,
    'Asia/Pontianak': 7,
    'Asia/Makassar': 8,
    'Asia/Jayapura': 9,
    'UTC': 0,
  };

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Offset of an IANA zone; falls back to the device offset.
  static Duration offsetOf(String? timezone) {
    final hours = _offsets[timezone];
    return hours == null
        ? DateTime.now().timeZoneOffset
        : Duration(hours: hours);
  }

  /// Wall-clock representation of [instant] in [timezone] (as a UTC DateTime).
  static DateTime toZone(DateTime instant, String? timezone) =>
      instant.toUtc().add(offsetOf(timezone));

  /// UTC instant of a local [date] + [hour]:[minute] in [timezone].
  static DateTime fromZone(
          DateTime date, int hour, int minute, String? timezone) =>
      DateTime.utc(date.year, date.month, date.day, hour, minute)
          .subtract(offsetOf(timezone));

  static String hm(DateTime instant, String? timezone) {
    final t = toZone(instant, timezone);
    return '${_two(t.hour)}:${_two(t.minute)}';
  }

  /// "Sat, 3 Oct 2026" from an ISO `YYYY-MM-DD` or a DateTime.
  static String date(Object value) {
    final d = value is DateTime ? value : DateTime.parse('$value');
    return '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  /// "3 Oct" short form.
  static String shortDate(Object value) {
    final d = value is DateTime ? value : DateTime.parse('$value');
    return '${d.day} ${_months[d.month - 1]}';
  }

  /// `YYYY-MM-DD` of a calendar date.
  static String iso(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';

  /// Today's calendar date in [timezone].
  static DateTime today(String? timezone) {
    final t = toZone(DateTime.now(), timezone);
    return DateTime(t.year, t.month, t.day);
  }

  /// "2h 30m".
  static String duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

import 'package:intl/intl.dart';

/// Display formatting helpers.
class Fmt {
  Fmt._();

  static final _dateTime = DateFormat('EEE, d MMM y • h:mm a');
  static final _date = DateFormat('d MMM y');
  static final _time = DateFormat('h:mm a');
  static final _money = NumberFormat.decimalPattern();

  static String dateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d);
  static String date(DateTime? d) => d == null ? '—' : _date.format(d);
  static String time(DateTime? d) => d == null ? '—' : _time.format(d);

  static String pkr(num? v) => v == null ? '—' : 'PKR ${_money.format(v.round())}';
  static String km(double v) => '${v.toStringAsFixed(v >= 100 ? 0 : 1)} km';

  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

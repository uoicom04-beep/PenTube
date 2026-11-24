import 'settings.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String fmtSeconds(int s) {
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, x = s % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(x)}' : '$m:${_two(x)}';
}

String fmtDuration(Duration d) => fmtSeconds(d.inSeconds < 0 ? 0 : d.inSeconds);

String fmtViews(int? n) {
  if (n == null || n <= 0) return '';
  final th = Settings.I.code == 'th';
  double d;
  String u;
  if (n >= 1000000000) {
    d = n / 1e9;
    u = th ? 'พันล้าน' : 'B';
  } else if (n >= 1000000) {
    d = n / 1e6;
    u = th ? 'ล้าน' : 'M';
  } else if (n >= 1000) {
    d = n / 1e3;
    u = th ? 'พัน' : 'K';
  } else {
    return '$n';
  }
  final s = d >= 10 ? d.toStringAsFixed(0) : d.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  return th ? '$s $u' : '$s$u';
}

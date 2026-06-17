import 'dart:math';

String newId() {
  final r = Random();
  return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${r.nextInt(1 << 32).toRadixString(36)}';
}

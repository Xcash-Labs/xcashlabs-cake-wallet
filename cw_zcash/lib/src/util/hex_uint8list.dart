import 'package:flutter/foundation.dart';

Uint8List hexToUint8List(final String hex) {
  if (hex.length % 2 != 0) {
    throw 'Odd number of hex digits';
  }
  final l = hex.length ~/ 2;
  final result = List.generate(l, (_) => 0x00);
  for (var i = 0; i < l; ++i) {
    final x = int.parse(hex.substring(2 * i, 2 * (i + 1)), radix: 16);
    if (x.isNaN) {
      throw 'Expected hex string';
    }
    result[i] = x;
  }
  return Uint8List.fromList(result);
}

String uint8ListToHex(final Uint8List bytes) {
  final buffer = StringBuffer();
  for (final b in bytes) {
    buffer.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

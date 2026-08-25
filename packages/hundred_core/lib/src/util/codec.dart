import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const String _b58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

/// Bitcoin-flavoured base58 used for DIDs and recovery keys. Chosen over
/// base64 because the alphabet has no visually ambiguous characters, which
/// matters when a user copies a recovery key off a screen by hand.
String base58Encode(List<int> input) {
  if (input.isEmpty) return '';

  var zeros = 0;
  while (zeros < input.length && input[zeros] == 0) {
    zeros++;
  }

  final digits = <int>[0];
  for (var i = zeros; i < input.length; i++) {
    var carry = input[i];
    for (var j = 0; j < digits.length; j++) {
      carry += digits[j] << 8;
      digits[j] = carry % 58;
      carry ~/= 58;
    }
    while (carry > 0) {
      digits.add(carry % 58);
      carry ~/= 58;
    }
  }

  final buffer = StringBuffer();
  for (var i = 0; i < zeros; i++) {
    buffer.write(_b58Alphabet[0]);
  }
  for (var i = digits.length - 1; i >= 0; i--) {
    buffer.write(_b58Alphabet[digits[i]]);
  }
  return buffer.toString();
}

Uint8List base58Decode(String input) {
  if (input.isEmpty) return Uint8List(0);

  var zeros = 0;
  while (zeros < input.length && input[zeros] == _b58Alphabet[0]) {
    zeros++;
  }

  final bytes = <int>[0];
  for (var i = zeros; i < input.length; i++) {
    final value = _b58Alphabet.indexOf(input[i]);
    if (value < 0) {
      throw FormatException('Invalid base58 character', input, i);
    }
    var carry = value;
    for (var j = 0; j < bytes.length; j++) {
      carry += bytes[j] * 58;
      bytes[j] = carry & 0xff;
      carry >>= 8;
    }
    while (carry > 0) {
      bytes.add(carry & 0xff);
      carry >>= 8;
    }
  }

  final out = Uint8List(zeros + bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    out[zeros + i] = bytes[bytes.length - 1 - i];
  }
  return out;
}

/// Deterministic JSON encoding: object keys sorted, no insignificant
/// whitespace. Two peers must derive byte-identical bodies from the same event
/// or every signature check across the network fails, so this is the one place
/// where map ordering is not allowed to be incidental.
String canonicalJson(Object? value) {
  final buffer = StringBuffer();
  _writeCanonical(buffer, value);
  return buffer.toString();
}

void _writeCanonical(StringBuffer out, Object? value) {
  if (value == null) {
    out.write('null');
  } else if (value is num) {
    if (value is double && value == value.roundToDouble() && value.isFinite) {
      out.write(value.toInt().toString());
    } else {
      out.write(jsonEncode(value));
    }
  } else if (value is bool) {
    out.write(value ? 'true' : 'false');
  } else if (value is String) {
    out.write(jsonEncode(value));
  } else if (value is List) {
    out.write('[');
    for (var i = 0; i < value.length; i++) {
      if (i > 0) out.write(',');
      _writeCanonical(out, value[i]);
    }
    out.write(']');
  } else if (value is Map) {
    final keys = value.keys.map((Object? k) => k.toString()).toList()..sort();
    out.write('{');
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) out.write(',');
      out
        ..write(jsonEncode(keys[i]))
        ..write(':');
      _writeCanonical(out, value[keys[i]]);
    }
    out.write('}');
  } else {
    throw ArgumentError.value(value, 'value', 'Not encodable as canonical JSON');
  }
}

/// SHA-256 over the canonical encoding, returned as lowercase hex.
String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();

import 'dart:convert';

/// Deterministic JSON encoding: object keys sorted, no insignificant
/// whitespace. Two maps with the same content give the same string whatever
/// order their keys were inserted in — which is what a cache key needs.
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
    throw ArgumentError.value(
        value, 'value', 'Not encodable as canonical JSON');
  }
}

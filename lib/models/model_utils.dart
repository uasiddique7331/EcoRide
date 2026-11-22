import 'package:cloud_firestore/cloud_firestore.dart';

/// Converts a Firestore value (Timestamp / DateTime / null) to [DateTime].
DateTime? asDate(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

String asString(Object? v, [String fallback = '']) => v is String ? v : fallback;

int asInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.round();
  return fallback;
}

double asDouble(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;

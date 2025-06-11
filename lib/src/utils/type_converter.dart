import 'package:document_client/document_client.dart';

/// Converts DynamoDB values to Dart native types
///
/// Handles automatic conversion of:
/// - ISO 8601 datetime strings to DateTime objects
/// - Nested maps and lists recursively
dynamic fromDynamoDB(dynamic value) {
  if (value is String) {
    // Try to parse ISO 8601 datetime strings
    if (DateTime.tryParse(value) != null) {
      return DateTime.parse(value);
    }
  }
  if (value is Map<String, dynamic>) {
    final entries = value.entries.map((entry) {
      return MapEntry<String, dynamic>(entry.key, fromDynamoDB(entry.value));
    });
    return Map<String, dynamic>.fromEntries(entries);
  }
  if (value is List) {
    return value.map(fromDynamoDB).toList();
  }
  return value;
}

/// Converts Dart native types to DynamoDB-compatible values
///
/// Handles automatic conversion of:
/// - DateTime objects to ISO 8601 strings
/// - Nested maps and lists recursively
dynamic toDynamoDB(dynamic value) {
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Map<String, dynamic>) {
    final entries = value.entries.map((entry) {
      return MapEntry<String, dynamic>(entry.key, toDynamoDB(entry.value));
    });
    return Map<String, dynamic>.fromEntries(entries);
  }
  if (value is List) {
    return value.map(toDynamoDB).toList();
  }
  return value;
}

/// Convert Dart values to DynamoDB AttributeValue for batch operations
AttributeValue toAttributeValue(dynamic value) {
  if (value is String) {
    return AttributeValue(s: value);
  } else if (value is num) {
    return AttributeValue(n: value.toString());
  } else if (value is bool) {
    return AttributeValue(boolValue: value);
  } else if (value is List) {
    return AttributeValue(l: value.map(toAttributeValue).toList());
  } else if (value is Map<String, dynamic>) {
    final mapValues = <String, AttributeValue>{};
    for (final entry in value.entries) {
      mapValues[entry.key] = toAttributeValue(entry.value);
    }
    return AttributeValue(m: mapValues);
  } else if (value == null) {
    return AttributeValue(nullValue: true);
  } else {
    // Fallback: convert to string
    return AttributeValue(s: value.toString());
  }
}

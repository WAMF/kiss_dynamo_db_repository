import 'package:document_client/document_client.dart';


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

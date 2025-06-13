/// Helper method to extract creation date from objects
/// Assumes objects have a 'created' field that is a DateTime
DateTime extractCreatedDate<T>(T object) {
  // Use reflection-like approach to get the created field
  // This is a bit hacky but necessary for generic sorting
  final objectStr = object.toString();
  final match = RegExp(r'created:\s*(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z?)').firstMatch(objectStr);
  if (match != null) {
    return DateTime.parse(match.group(1)!);
  }

  // Alternative: try to access as dynamic
  try {
    final dynamic obj = object;
    if (obj is Map && obj.containsKey('created')) {
      final created = obj['created'];
      if (created is DateTime) return created;
      if (created is String) return DateTime.parse(created);
    }
    // Try to access created property directly
    return (obj as dynamic).created as DateTime;
  } catch (e) {
    // If all else fails, use current time (objects will be in random order)
    return DateTime.now();
  }
}

/// Extract ID from object for sorting
String extractId<T>(T object) {
  try {
    final dynamic obj = object;
    return (obj as dynamic).id as String;
  } catch (e) {
    return '';
  }
}

/// Extract name from object for debugging
String extractName<T>(T object) {
  try {
    final dynamic obj = object;
    return (obj as dynamic).name as String;
  } catch (e) {
    return 'unknown';
  }
}

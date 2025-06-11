import 'package:kiss_repository/kiss_repository.dart';
import 'package:uuid/uuid.dart';

class DynamoDBIdentifiedObject<T> extends IdentifiedObject<T> {
  DynamoDBIdentifiedObject(T object, this._updateObjectWithId) : super('', object);

  final T Function(T object, String id) _updateObjectWithId;
  String? _cachedId;
  T? _cachedUpdatedObject;

  @override
  String get id {
    _cachedId ??= _generateDynamoDBId();
    return _cachedId!;
  }

  @override
  T get object {
    if (_cachedUpdatedObject == null) {
      final generatedId = id; // This will generate and cache the ID if needed
      _cachedUpdatedObject = _updateObjectWithId(super.object, generatedId);
    }
    return _cachedUpdatedObject!;
  }

  String _generateDynamoDBId() => const Uuid().v4();

  factory DynamoDBIdentifiedObject.create(T object, T Function(T object, String id) updateObjectWithId) =>
      DynamoDBIdentifiedObject(object, updateObjectWithId);
}

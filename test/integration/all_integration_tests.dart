import 'package:test/test.dart';

import 'dynamodb_specific_tests.dart' as dynamodb_specific_tests;
import 'kiss_tests.dart' as kiss_tests;

void main() {
  group('All DynamoDB Integration Tests', () {
    // KISS Repository Tests using Factory Pattern
    group('KISS Repository Tests', kiss_tests.main);

    // DynamoDB-specific implementation tests
    group('DynamoDB-Specific Tests', dynamodb_specific_tests.main);
  });
}

import 'package:test/test.dart';

import 'kiss_tests.dart' as kiss_tests;

void main() {
  group('All DynamoDB Integration Tests', () {
    group('KISS Tests', kiss_tests.main);
  });
}

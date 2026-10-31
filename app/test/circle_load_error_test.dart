import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:circlo/features/circles/circle_load_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('permission denied points to the Firestore Rules deployment', () {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );

    expect(circlesLoadErrorMessage(error), contains('firebase/firestore.rules'));
    expect(circlesLoadErrorMessage(error), contains('permission-denied'));
  });

  test('failed precondition points to the collection-group index', () {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'failed-precondition',
      message: 'The query requires an index.',
    );

    final message = circlesLoadErrorMessage(error);
    expect(message, contains('firebase/firestore.indexes.json'));
    expect(message, contains('members.uid collection-group index'));
    expect(message, contains('The query requires an index.'));
  });

  test('temporary Firebase failures explain the connection retry', () {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );

    final message = circlesLoadErrorMessage(error);
    expect(message, contains('Check your connection and retry'));
    expect(message, contains('(unavailable)'));
  });

  test('unknown failures retain a useful diagnostic', () {
    final message = circlesLoadErrorMessage(StateError('unexpected'));

    expect(message, contains('StateError'));
    expect(message, contains('unexpected'));
  });
}

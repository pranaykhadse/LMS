import 'package:flutter_test/flutter_test.dart';
import 'package:lms/app/features/payment/model/purchase_record.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Unit tests for [PurchaseRecord] — model serialization & helpers.
///
/// Pure Dart logic, no platform setup needed.
/// Run with:
///   flutter test test/payment/purchase_record_test.dart
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  // ─── Fixtures ────────────────────────────────────────────────────────────

  final sampleRecord = PurchaseRecord(
    productId: 'live.leadershipedge.app.course_1',
    courseId: 1,
    purchasedAt: DateTime(2026, 4, 7, 12, 0, 0),
    transactionId: 'txn_abc123',
  );

  // ─── toJson ───────────────────────────────────────────────────────────────

  group('PurchaseRecord.toJson', () {
    test('contains all expected keys', () {
      final json = sampleRecord.toJson();
      expect(json.containsKey('product_id'), isTrue);
      expect(json.containsKey('course_id'), isTrue);
      expect(json.containsKey('purchased_at'), isTrue);
      expect(json.containsKey('transaction_id'), isTrue);
    });

    test('serializes productId correctly', () {
      expect(
        sampleRecord.toJson()['product_id'],
        equals('live.leadershipedge.app.course_1'),
      );
    });

    test('serializes courseId correctly', () {
      expect(sampleRecord.toJson()['course_id'], equals(1));
    });

    test('serializes transactionId correctly', () {
      expect(
        sampleRecord.toJson()['transaction_id'],
        equals('txn_abc123'),
      );
    });

    test('serializes purchasedAt as ISO-8601 string', () {
      final raw = sampleRecord.toJson()['purchased_at'];
      expect(raw, isA<String>());
      // Verify it parses back to the same DateTime.
      expect(DateTime.parse(raw as String), equals(sampleRecord.purchasedAt));
    });
  });

  // ─── fromJson ─────────────────────────────────────────────────────────────

  group('PurchaseRecord.fromJson', () {
    test('deserializes all fields correctly', () {
      final json = sampleRecord.toJson();
      final restored = PurchaseRecord.fromJson(json);

      expect(restored.productId, equals(sampleRecord.productId));
      expect(restored.courseId, equals(sampleRecord.courseId));
      expect(restored.transactionId, equals(sampleRecord.transactionId));
      expect(restored.purchasedAt, equals(sampleRecord.purchasedAt));
    });
  });

  // ─── copyWith ─────────────────────────────────────────────────────────────

  group('PurchaseRecord.copyWith', () {
    test('returns a new instance with updated courseId', () {
      final updated = sampleRecord.copyWith(courseId: 99);
      expect(updated.courseId, equals(99));
      // Original should be unchanged.
      expect(sampleRecord.courseId, equals(1));
    });

    test('preserves unchanged fields', () {
      final updated = sampleRecord.copyWith(transactionId: 'txn_NEW');
      expect(updated.productId, equals(sampleRecord.productId));
      expect(updated.courseId, equals(sampleRecord.courseId));
      expect(updated.purchasedAt, equals(sampleRecord.purchasedAt));
    });
  });

  // ─── List serialization ───────────────────────────────────────────────────

  group('PurchaseRecord list serialization', () {
    final record2 = sampleRecord.copyWith(
      courseId: 2,
      productId: 'live.leadershipedge.app.course_2',
      transactionId: 'txn_xyz789',
    );
    final records = [sampleRecord, record2];

    test('listToRawJson produces a non-empty string', () {
      final raw = PurchaseRecord.listToRawJson(records);
      expect(raw, isNotEmpty);
    });

    test('listFromRawJson restores the correct count', () {
      final raw = PurchaseRecord.listToRawJson(records);
      final restored = PurchaseRecord.listFromRawJson(raw);
      expect(restored.length, equals(2));
    });

    test('listFromRawJson restores correct courseIds', () {
      final raw = PurchaseRecord.listToRawJson(records);
      final restored = PurchaseRecord.listFromRawJson(raw);
      expect(restored[0].courseId, equals(1));
      expect(restored[1].courseId, equals(2));
    });

    test('listFromRawJson restores correct transactionIds', () {
      final raw = PurchaseRecord.listToRawJson(records);
      final restored = PurchaseRecord.listFromRawJson(raw);
      expect(restored[0].transactionId, equals('txn_abc123'));
      expect(restored[1].transactionId, equals('txn_xyz789'));
    });

    test('round-trips an empty list', () {
      final raw = PurchaseRecord.listToRawJson([]);
      final restored = PurchaseRecord.listFromRawJson(raw);
      expect(restored, isEmpty);
    });
  });

  // ─── toString ─────────────────────────────────────────────────────────────

  group('PurchaseRecord.toString', () {
    test('includes courseId and transactionId', () {
      final str = sampleRecord.toString();
      expect(str, contains('1'));
      expect(str, contains('txn_abc123'));
    });
  });
}

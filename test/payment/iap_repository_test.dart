// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:lms/app/features/payment/repository/iap_repository.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Unit tests for [IAPRepository] static helpers.
///
/// These tests cover pure Dart logic and require NO platform/device setup.
/// Run with:
///   flutter test test/payment/iap_repository_test.dart
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  // ─── productIdForCourse ──────────────────────────────────────────────────

  group('IAPRepository.productIdForCourse', () {
    test('generates the correct product ID for course 1', () {
      expect(
        IAPRepository.productIdForCourse(1),
        equals('live.leadershipedge.app.course_1'),
      );
    });

    test('generates the correct product ID for course 42', () {
      expect(
        IAPRepository.productIdForCourse(42),
        equals('live.leadershipedge.app.course_42'),
      );
    });

    test('generates the correct product ID for a large course ID', () {
      expect(
        IAPRepository.productIdForCourse(99999),
        equals('live.leadershipedge.app.course_99999'),
      );
    });

    test('always starts with the bundle-ID prefix', () {
      final id = IAPRepository.productIdForCourse(7);
      expect(id.startsWith('live.leadershipedge.app.course_'), isTrue);
    });
  });

  // ─── courseIdFromProductId ────────────────────────────────────────────────

  group('IAPRepository.courseIdFromProductId', () {
    test('extracts course ID 1 correctly', () {
      expect(
        IAPRepository.courseIdFromProductId(
            'live.leadershipedge.app.course_1'),
        equals(1),
      );
    });

    test('extracts course ID 42 correctly', () {
      expect(
        IAPRepository.courseIdFromProductId(
            'live.leadershipedge.app.course_42'),
        equals(42),
      );
    });

    test('returns null for an unrelated product ID', () {
      expect(
        IAPRepository.courseIdFromProductId('com.example.other.product'),
        isNull,
      );
    });

    test('returns null for an empty string', () {
      expect(
        IAPRepository.courseIdFromProductId(''),
        isNull,
      );
    });

    test('returns null when suffix is not a number', () {
      expect(
        IAPRepository.courseIdFromProductId(
            'live.leadershipedge.app.course_abc'),
        isNull,
      );
    });

    test('returns null when suffix is a float', () {
      expect(
        IAPRepository.courseIdFromProductId(
            'live.leadershipedge.app.course_1.5'),
        isNull,
      );
    });
  });

  // ─── Round-trip ───────────────────────────────────────────────────────────

  group('productIdForCourse / courseIdFromProductId round-trip', () {
    final testIds = [1, 5, 100, 9999];

    for (final courseId in testIds) {
      test('round-trip succeeds for courseId=$courseId', () {
        final productId = IAPRepository.productIdForCourse(courseId);
        final extracted = IAPRepository.courseIdFromProductId(productId);
        expect(extracted, equals(courseId),
            reason:
                'productId "$productId" should round-trip back to $courseId');
      });
    }
  });
}

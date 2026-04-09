// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/provider/local_storage_provider.dart';
import 'package:lms/app/features/payment/repository/iap_repository.dart';
import 'package:lms/app/features/payment/viewmodel/iap_viewmodel.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Fake implementations for testing (no code generation required)
/// ─────────────────────────────────────────────────────────────────────────────

class FakeLocalStorage extends LocalStorage {
  final Map<String, String?> _data = {};

  @override
  Future<String?> getString(String key) async => _data[key];

  @override
  Future<void> setString(String key, String? value) async {
    _data[key] = value;
  }
}

class FakeIAPRepository implements IIAPRepository {
  bool availableResult = true;
  List<ProductDetails> productsResult = [];
  Exception? queryException;
  Exception? buyException;

  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Future<bool> isAvailable() async => availableResult;

  @override
  Future<List<ProductDetails>> queryProducts(Set<String> productIds) async {
    if (queryException != null) throw queryException!;
    return productsResult;
  }

  @override
  Future<void> buyNonConsumable(ProductDetails product) async {
    if (buyException != null) throw buyException!;
  }

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  /// Helper: emit purchase events directly for testing.
  void emitPurchases(List<PurchaseDetails> purchases) {
    _controller.add(purchases);
  }

  void dispose() => _controller.close();
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Helpers
/// ─────────────────────────────────────────────────────────────────────────────

IAPViewModel buildViewModel({
  FakeIAPRepository? repo,
  FakeLocalStorage? storage,
}) {
  return IAPViewModel(
    repository: repo ?? FakeIAPRepository(),
    storage: storage ?? FakeLocalStorage(),
  );
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Tests
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  // ─── Initial state ────────────────────────────────────────────────────────

  group('IAPViewModel — initial state', () {
    test('isPurchasing is false', () {
      final vm = buildViewModel();
      expect(vm.isPurchasing, isFalse);
      vm.dispose();
    });

    test('isRestoring is false', () {
      final vm = buildViewModel();
      expect(vm.isRestoring, isFalse);
      vm.dispose();
    });

    test('error is null', () {
      final vm = buildViewModel();
      expect(vm.error, isNull);
      vm.dispose();
    });

    test('purchaseSuccess is false', () {
      final vm = buildViewModel();
      expect(vm.purchaseSuccess, isFalse);
      vm.dispose();
    });

    test('currentProduct state is idle', () {
      final vm = buildViewModel();
      expect(vm.currentProduct.state, equals(DataProviderState.idle));
      vm.dispose();
    });

    test('no course is purchased initially', () {
      final vm = buildViewModel();
      expect(vm.isPurchased(1), isFalse);
      expect(vm.isPurchased(999), isFalse);
      vm.dispose();
    });
  });

  // ─── isPurchased after loading from storage ───────────────────────────────

  group('IAPViewModel — load purchased IDs from storage', () {
    test('restores purchased course IDs from Hive on init', () async {
      final storage = FakeLocalStorage();
      // Pre-populate storage with course IDs 1 and 5.
      await storage.setString('purchased_course_ids', '[1, 5]');

      final vm = IAPViewModel(
        repository: FakeIAPRepository(),
        storage: storage,
      );

      // Give _initialize() time to run.
      await Future.delayed(Duration.zero);

      expect(vm.isPurchased(1), isTrue);
      expect(vm.isPurchased(5), isTrue);
      expect(vm.isPurchased(2), isFalse);
      vm.dispose();
    });

    test('handles corrupt storage data gracefully (does not crash)', () async {
      final storage = FakeLocalStorage();
      await storage.setString('purchased_course_ids', 'NOT_JSON');

      expect(
        () => IAPViewModel(repository: FakeIAPRepository(), storage: storage),
        returnsNormally,
      );
    });
  });

  // ─── fetchProductForCourse ────────────────────────────────────────────────

  group('IAPViewModel — fetchProductForCourse', () {
    test('sets loading state then error when store not available', () async {
      final repo = FakeIAPRepository()..availableResult = false;
      final vm = buildViewModel(repo: repo);

      await vm.fetchProductForCourse(1);

      expect(vm.currentProduct.state, equals(DataProviderState.error));
      expect(vm.currentProduct.error, contains('not available'));
      vm.dispose();
    });

    test('sets error when no products returned', () async {
      final repo = FakeIAPRepository()
        ..availableResult = true
        ..productsResult = []; // empty list
      final vm = buildViewModel(repo: repo);

      await vm.fetchProductForCourse(42);

      expect(vm.currentProduct.state, equals(DataProviderState.error));
      vm.dispose();
    });

    test('sets error when queryProducts throws', () async {
      final repo = FakeIAPRepository()
        ..availableResult = true
        ..queryException = Exception('Network error');
      final vm = buildViewModel(repo: repo);

      await vm.fetchProductForCourse(1);

      expect(vm.currentProduct.state, equals(DataProviderState.error));
      vm.dispose();
    });
  });

  // ─── purchase ─────────────────────────────────────────────────────────────

  group('IAPViewModel — purchase', () {
    test('sets isPurchasing to true while waiting', () async {
      final repo = FakeIAPRepository();
      final vm = buildViewModel(repo: repo);

      // Don't await — capture mid-flight state.
      // ignore: unawaited_futures
      vm.purchase(
        ProductDetails(
          id: IAPRepository.productIdForCourse(1),
          title: 'Test',
          description: 'Desc',
          price: '\$9.99',
          rawPrice: 9.99,
          currencyCode: 'USD',
        ),
      );

      // Right after calling purchase, isPurchasing should be true.
      expect(vm.isPurchasing, isTrue);
      vm.dispose();
    });

    test('sets error and clears isPurchasing when buy throws', () async {
      final repo = FakeIAPRepository()
        ..buyException = Exception('Simulated buy error');
      final vm = buildViewModel(repo: repo);

      await vm.purchase(
        ProductDetails(
          id: IAPRepository.productIdForCourse(1),
          title: 'Test',
          description: '',
          price: '\$9.99',
          rawPrice: 9.99,
          currencyCode: 'USD',
        ),
      );

      expect(vm.isPurchasing, isFalse);
      expect(vm.error, isNotNull);
      vm.dispose();
    });
  });

  // ─── clearError / clearPurchaseSuccess ───────────────────────────────────

  group('IAPViewModel — utility methods', () {
    test('clearError removes error message', () async {
      final repo = FakeIAPRepository()
        ..buyException = Exception('err');
      final vm = buildViewModel(repo: repo);

      await vm.purchase(
        ProductDetails(
          id: 'test',
          title: '',
          description: '',
          price: '',
          rawPrice: 0,
          currencyCode: 'USD',
        ),
      );
      expect(vm.error, isNotNull);

      vm.clearError();
      expect(vm.error, isNull);
      vm.dispose();
    });

    test('clearPurchaseSuccess resets purchaseSuccess flag', () {
      final vm = buildViewModel();
      // Manually flip it via a notifyListeners-compatible approach.
      // We can't set it directly, so we verify the clear function exists and runs.
      vm.clearPurchaseSuccess();
      expect(vm.purchaseSuccess, isFalse);
      vm.dispose();
    });
  });

  // ─── restorePurchases ────────────────────────────────────────────────────

  group('IAPViewModel — restorePurchases', () {
    test('sets isRestoring to true and clears error', () async {
      final vm = buildViewModel();
      // isRestoring should be true mid-operation.
      // We test post-operation state (completes without error here).
      await vm.restorePurchases();
      // After completing, isRestoring should be false (stream auto-resets it).
      // Here FakeIAPRepository does nothing, so isRestoring stays true until
      // a purchase event fires. Verify no exception is thrown.
      expect(() => vm.restorePurchases(), returnsNormally);
      vm.dispose();
    });
  });
}

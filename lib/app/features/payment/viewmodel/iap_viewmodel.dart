import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/provider/local_storage_provider.dart';
import 'package:lms/app/features/payment/repository/iap_repository.dart';

/// Hive key used to persist purchased course IDs across sessions.
const _kPurchasedIdsKey = 'purchased_course_ids';

/// ─────────────────────────────────────────────────────────────────────────────
/// IAPViewModel
///
/// Responsibilities:
///  • Listen to the platform purchase stream (App Store / Google Play)
///  • Persist purchased course IDs to local Hive storage
///  • Provide [isPurchased(courseId)] to gate course access in the UI
///  • Expose [fetchProductForCourse], [purchase], and [restorePurchases]
///    actions for [PurchasePage]
/// ─────────────────────────────────────────────────────────────────────────────
class IAPViewModel extends ChangeNotifier {
  // ─── Riverpod provider ────────────────────────────────────────────────────

  static final provider = ChangeNotifierProvider<IAPViewModel>((ref) {
    return IAPViewModel(
      repository: IAPRepository(), // uses InAppPurchase.instance by default
      storage: ref.watch(LocalStorage.provider),
    );
  });

  // ─── Constructor ──────────────────────────────────────────────────────────

  IAPViewModel({
    required IIAPRepository repository,
    required LocalStorage storage,
  })  : _repository = repository,
        _storage = storage {
    _initialize();
  }

  final IIAPRepository _repository;
  final LocalStorage _storage;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  // ─── Private state ────────────────────────────────────────────────────────

  /// Set of course IDs the user has already purchased (persisted in Hive).
  Set<int> _purchasedCourseIds = {};

  /// State of the currently displayed product (for [PurchasePage]).
  DataState<ProductDetails> _currentProduct = DataState.idle();

  bool _isPurchasing = false;
  bool _isRestoring = false;
  String? _error;

  /// Flips to `true` when a purchase/restore completes successfully.
  /// [PurchasePage] listens for this to show a success toast and pop.
  bool _purchaseSuccess = false;

  // ─── Public getters ───────────────────────────────────────────────────────

  /// Whether [courseId] has been purchased by the current user.
  bool isPurchased(int courseId) => _purchasedCourseIds.contains(courseId);

  /// Product details state for the currently viewed course in [PurchasePage].
  DataState<ProductDetails> get currentProduct => _currentProduct;

  bool get isPurchasing => _isPurchasing;
  bool get isRestoring => _isRestoring;
  String? get error => _error;
  bool get purchaseSuccess => _purchaseSuccess;

  // ─── Initialization ───────────────────────────────────────────────────────

  Future<void> _initialize() async {
    await _loadPurchasedCourseIds();
    _listenToPurchases();
  }

  /// Loads previously purchased course IDs from Hive on app start.
  Future<void> _loadPurchasedCourseIds() async {
    try {
      final raw = await _storage.getString(_kPurchasedIdsKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> ids = jsonDecode(raw) as List<dynamic>;
        _purchasedCourseIds = ids.whereType<int>().toSet();
        notifyListeners();
      }
    } catch (e) {
      log('IAPViewModel: Could not load purchased IDs — $e');
    }
  }

  /// Persists purchased course IDs to Hive.
  Future<void> _savePurchasedCourseIds() async {
    try {
      await _storage.setString(
        _kPurchasedIdsKey,
        jsonEncode(_purchasedCourseIds.toList()),
      );
    } catch (e) {
      log('IAPViewModel: Could not save purchased IDs — $e');
    }
  }

  // ─── Purchase stream ──────────────────────────────────────────────────────

  /// Attaches a single listener to the platform purchase stream.
  /// This listener must remain active for the lifetime of the app so that
  /// pending purchases (e.g. from a previous session) are processed.
  void _listenToPurchases() {
    _purchaseSubscription = _repository.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) {
        log('IAPViewModel: Purchase stream error — $e');
        _error = 'Purchase stream error. Please restart the app.';
        _isPurchasing = false;
        _isRestoring = false;
        notifyListeners();
      },
    );
  }

  /// Handles incoming events from the platform purchase stream.
  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Mark as complete with the store and update local state.
          _handleSuccessfulPurchase(purchase);
          break;

        case PurchaseStatus.error:
          _error =
              purchase.error?.message ?? 'Purchase failed. Please try again.';
          _isPurchasing = false;
          _isRestoring = false;
          notifyListeners();
          break;

        case PurchaseStatus.canceled:
          _isPurchasing = false;
          _isRestoring = false;
          notifyListeners();
          break;

        case PurchaseStatus.pending:
          // Purchase is awaiting approval (e.g. parental controls).
          // Keep loading UI visible; a follow-up event will arrive.
          break;
      }
    }
  }

  /// Called when a purchase or restore succeeds.
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    // Extract courseId embedded in the product ID.
    final courseId = IAPRepository.courseIdFromProductId(purchase.productID);
    if (courseId != null) {
      _purchasedCourseIds.add(courseId);
      await _savePurchasedCourseIds();
    }

    _purchaseSuccess = true;
    _isPurchasing = false;
    _isRestoring = false;
    _error = null;
    notifyListeners();

    // ⚠️  Apple / Google require completePurchase to be called or the
    //     purchase will be re-delivered on the next app launch.
    await _repository.completePurchase(purchase);
  }

  // ─── Public actions ───────────────────────────────────────────────────────

  /// Fetches the [ProductDetails] for [courseId] from the App Store /
  /// Google Play and updates [currentProduct].
  ///
  /// Call this from [PurchasePage.initState].
  Future<void> fetchProductForCourse(int courseId) async {
    _currentProduct = DataState.loading();
    _purchaseSuccess = false;
    _error = null;
    notifyListeners();

    try {
      final isAvailable = await _repository.isAvailable();
      if (!isAvailable) {
        _currentProduct = DataState.onError(
          'The App Store is not available on this device.',
        );
        notifyListeners();
        return;
      }

      final productId = IAPRepository.productIdForCourse(courseId);
      final products = await _repository.queryProducts({productId});

      if (products.isEmpty) {
        _currentProduct = DataState.onError(
          'Product not found. Please contact support or check your '
          'App Store Connect configuration.',
        );
      } else {
        _currentProduct = DataState.onData(products.first);
      }
    } catch (e) {
      _currentProduct = DataState.onError(e.toString());
    }

    notifyListeners();
  }

  /// Initiates a non-consumable purchase flow for [product].
  /// Apple / Google native payment sheet will appear.
  /// The result arrives via [purchaseStream].
  Future<void> purchase(ProductDetails product) async {
    _isPurchasing = true;
    _purchaseSuccess = false;
    _error = null;
    notifyListeners();

    try {
      await _repository.buyNonConsumable(product);
      // ↑ Returns immediately; outcome arrives via _onPurchaseUpdate.
    } catch (e) {
      _isPurchasing = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Restores all previous non-consumable purchases for the signed-in user.
  /// Call this when the user taps "Restore Purchases".
  Future<void> restorePurchases() async {
    _isRestoring = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.restorePurchases();
      // ↑ Results arrive via _onPurchaseUpdate.
    } catch (e) {
      _isRestoring = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  // ─── Utility ──────────────────────────────────────────────────────────────

  /// Clears the current error message (call after showing a toast).
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Resets the purchase-success flag (call after navigating away).
  void clearPurchaseSuccess() {
    _purchaseSuccess = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}

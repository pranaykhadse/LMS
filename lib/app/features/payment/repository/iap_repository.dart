import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Abstract interface – allows easy mocking in unit tests
/// ─────────────────────────────────────────────────────────────────────────────
abstract class IIAPRepository {
  Future<bool> isAvailable();
  Future<List<ProductDetails>> queryProducts(Set<String> productIds);
  Future<void> buyNonConsumable(ProductDetails product);
  Future<void> restorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
  Stream<List<PurchaseDetails>> get purchaseStream;
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Concrete implementation backed by [InAppPurchase]
/// ─────────────────────────────────────────────────────────────────────────────
class IAPRepository implements IIAPRepository {
  /// App's bundle ID prefix – must match Apple App Store / Google Play Console
  static const String _productIdPrefix = 'live.leadershipedge.app.course_';

  final InAppPurchase _iap;

  /// Pass a custom [InAppPurchase] instance for testing; defaults to the
  /// platform singleton [InAppPurchase.instance].
  IAPRepository({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  // ─── Static helpers ──────────────────────────────────────────────────────

  /// Build the App Store product ID for a given [courseId].
  /// Format: `live.leadershipedge.app.course_<courseId>`
  ///
  /// ⚠️  This ID must exactly match what you created in
  ///     App Store Connect → In-App Purchases.
  static String productIdForCourse(int courseId) =>
      '$_productIdPrefix$courseId';

  /// Extract the [courseId] from a product ID produced by [productIdForCourse].
  /// Returns `null` if the [productId] doesn't match the expected format.
  static int? courseIdFromProductId(String productId) {
    if (!productId.startsWith(_productIdPrefix)) return null;
    return int.tryParse(productId.substring(_productIdPrefix.length));
  }

  // ─── IIAPRepository implementation ───────────────────────────────────────

  /// Returns `false` on web and unsupported platforms; `true` on iOS/Android.
  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    return _iap.isAvailable();
  }

  /// Queries product details from App Store / Google Play for the given IDs.
  /// Throws an [Exception] if the store returns an error.
  @override
  Future<List<ProductDetails>> queryProducts(Set<String> productIds) async {
    final ProductDetailsResponse response =
        await _iap.queryProductDetails(productIds);

    if (response.error != null) {
      throw Exception(
        'Store error while fetching products: ${response.error!.message}',
      );
    }
    return response.productDetails;
  }

  /// Initiates a non-consumable purchase (one-time unlock) for [product].
  /// The result arrives asynchronously via [purchaseStream].
  @override
  Future<void> buyNonConsumable(ProductDetails product) async {
    final PurchaseParam param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Restores all previous non-consumable purchases for the current user.
  /// Results arrive via [purchaseStream].
  @override
  Future<void> restorePurchases() => _iap.restorePurchases();

  /// Marks a purchase as complete with the platform store.
  /// Must be called for every [PurchaseDetails] with a terminal status
  /// (`purchased` or `restored`).
  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);

  /// Stream of purchase updates from App Store / Google Play.
  /// Listen to this ONCE at app level to handle all purchase events.
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;
}

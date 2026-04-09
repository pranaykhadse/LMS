import 'package:flutter_modular/flutter_modular.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app_module.dart';

import '../view/purchase_page.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// PaymentModule
///
/// Registered in [AppModule] under the route [AppModule.payment] ("/payment").
///
/// Routes:
///   /payment/purchase  →  [PurchasePage]
///
/// Navigation usage:
///   ```dart
///   Modular.to.pushNamed(
///     PaymentModule.purchaseRoute,
///     arguments: course,   // pass the full Course object
///   );
///   ```
/// ─────────────────────────────────────────────────────────────────────────────
class PaymentModule extends Module {
  /// Relative path for the purchase screen (within this module).
  static const _purchase = '/purchase';

  /// Full absolute route string for the purchase screen.
  /// Use this when navigating from outside the payment module.
  static String get purchaseRoute => AppModule.payment + _purchase;

  @override
  void routes(RouteManager r) {
    r.child(
      _purchase,
      child: (context) {
        // The Course object is passed via Modular.args.data when navigating.
        final course = Modular.args.data as Course;
        return PurchasePage(course: course);
      },
    );
  }
}

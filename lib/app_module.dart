import 'package:flutter_modular/flutter_modular.dart';
import 'package:lms/app/features/authentication/module/auth_module.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/payment/module/payment_module.dart';

import 'app/features/startup/view/startup_view.dart';

class AppModule extends Module {
  static const auth = "/auth";
  static const home = "/home";

  /// Root route for the payment feature module.
  static const payment = "/payment";

  @override
  void binds(i) {}

  @override
  void routes(r) {
    r.child("/", child: (context) => const StartupView());
    r.module(auth, module: AuthModule());
    r.module(home, module: CoursesModule());
    r.module(payment, module: PaymentModule());
  }
}

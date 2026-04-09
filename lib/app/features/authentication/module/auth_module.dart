import 'package:flutter_modular/flutter_modular.dart';
import 'package:lms/app/features/authentication/view/index.dart';


class AuthModule extends Module {
  @override
  void routes(RouteManager r) {
    r.child("/", child: (context) => SignInPage());
  }
}

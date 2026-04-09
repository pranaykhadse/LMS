import 'package:flutter/cupertino.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app_module.dart';

class StartupViewModel extends ChangeNotifier {
  static final provider = ChangeNotifierProvider.autoDispose<StartupViewModel>(
    (ref) => StartupViewModel(ref: ref),
  );

  final Ref ref;

  StartupViewModel({required this.ref}) {
    initialize();
  }

  Future<void> initialize() async {
    try {
      await ref.read(InternetConnectionProvider.provider).intialize();
    } catch (_) {
      // Connectivity check failure is non-fatal — proceed as offline.
    }
    try {
      await ref.read(AuthStateNotifier.provider.notifier).initialize();
    } catch (_) {
      // Auth init failure is non-fatal — treat as logged-out.
    }
    await Future.delayed(const Duration(seconds: 1));
    if (ref.read(AuthStateNotifier.provider) != null) {
      Modular.to.navigate(CoursesModule.construct(CoursesModule.root));
    } else {
      Modular.to.navigate(AppModule.auth);
    }
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/vm_helper/offline_vm_helper.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/features/authentication/repository/auth_repository.dart';

import '../../../core/logic/form/form_element_mixin.dart';
import '../app_state/auth_state_provider.dart';

class SignInViewModel with FormHandlerMixin<bool>, ChangeNotifier {
  static final provider = ChangeNotifierProvider<SignInViewModel>((ref) {
    return SignInViewModel(
      ref.watch(AuthRepository.provider),
      ref.watch(AuthStateNotifier.provider.notifier),
    );
  });
  final AuthRepository authenticator;
  final AuthStateNotifier authStateProvider;

  SignInViewModel(this.authenticator, this.authStateProvider);

  final email = TextEditingController(
    text: kDebugMode ? "shilpatests@gmail.com" : null,
  );
  final password = TextEditingController(
    text: kDebugMode ? "1234567890" : null,
  );

  final isPasswordHidden = ValueNotifier(true);

  bool rememberMe = false;
  void togglePasswordVisibility() {
    isPasswordHidden.value = !isPasswordHidden.value;
  }

  Future<void> signIn() async {
    await authStateProvider.login(email: email.text, password: password.text);
  }

  @override
  Future<bool> save(BuildContext context) async {
    await signIn();
    return true;
  }

  void toggleRememberMe(bool? value) {
    rememberMe = value ?? true;
    notifyListeners();
  }

}

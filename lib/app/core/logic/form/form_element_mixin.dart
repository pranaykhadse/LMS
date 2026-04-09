import 'package:flutter/cupertino.dart';

import '../../views/elements/buttons/button_controller.dart';

mixin FormHandlerMixin<T> {
  ///
  /// Form key for current form
  ///
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  ButtonController submitButtonController = ButtonController();
  ButtonController cancelButtonController = ButtonController();

  ///
  ///
  /// [submit] function should be called when submit button is pressed
  ///
  Future<T?> submit(BuildContext context) async {
    if (!(formKey.currentState?.validate() ?? false)) return null;
    submitButtonController.startLoading();
    cancelButtonController.disable();
    try {
      final data = await save(context);
      submitButtonController.enable();
      cancelButtonController.enable();
      return data;
    } catch (e) {
      submitButtonController.enable();
      cancelButtonController.enable();

      rethrow;
    }
  }

  ///
  ///
  /// [save] function will be called by submit function when form is valid.
  ///
  @protected
  Future<T?> save(BuildContext context);
}

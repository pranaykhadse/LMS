import 'package:flutter/cupertino.dart';

enum ButtonState { loading, active, inactive }

class ButtonController {
  final ValueNotifier<ButtonState> state = ValueNotifier(ButtonState.active);

  void startLoading() {
    state.value = ButtonState.loading;
  }

  void disable() {
    state.value = ButtonState.inactive;
  }

  void enable() {
    state.value = ButtonState.active;
  }
}

class AdminButtonTheme {
  final Widget Function(BuildContext context)? loader;

  AdminButtonTheme({
    this.loader,
  });
}

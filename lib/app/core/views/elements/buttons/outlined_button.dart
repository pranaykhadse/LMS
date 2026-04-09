import 'package:flutter/material.dart';

import 'button_controller.dart';
import 'elevated_button.dart';

// ignore: must_be_immutable
class AdminOutlinedResponsiveButton extends StatelessWidget {
  final Widget child;
  final Widget? loadingChild;
  final void Function()? onPressed;
  final ButtonController? controller;
  final ButtonStyle? buttonStyle;
  const AdminOutlinedResponsiveButton(
      {Key? key,
      required this.child,
      this.loadingChild,
      required this.onPressed,
      this.controller,
      this.buttonStyle,})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ButtonState>(
      valueListenable: controller?.state ?? ValueNotifier(ButtonState.active),
      builder: (context, value, _) {
        // switch (value) {
        //   case ButtonState.loading:
        return AbsorbPointer(
          absorbing: value == ButtonState.loading,
          child: OutlinedButton(
              style: buttonStyle,
              onPressed: value == ButtonState.inactive ? null : onPressed,
              child: value == ButtonState.loading
                  ? loadingChild ?? const CircleLoader()
                  : child),
        );
      },
    );
  }
}

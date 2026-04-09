import 'package:flutter/material.dart';

import 'button_controller.dart';

// ignore: must_be_immutable
class AdminElevatedResponsiveButton extends StatelessWidget {
  final Widget child;
  final Widget? loadingChild;
  final void Function()? onPressed;
  final ButtonStyle? buttonStyle;
  final ButtonController? controller;
  const AdminElevatedResponsiveButton({
    super.key,
    required this.child,
    this.loadingChild,
    required this.onPressed,
    this.controller,
    this.buttonStyle,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      child: ValueListenableBuilder<ButtonState>(
        valueListenable: controller?.state ?? ValueNotifier(ButtonState.active),
        builder: (context, value, _) {
          // switch (value) {
          //   case ButtonState.loading:
          return AbsorbPointer(
            absorbing: value == ButtonState.loading,
            child: ElevatedButton(
              style: buttonStyle,
              onPressed: value == ButtonState.inactive ? null : onPressed,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: value == ButtonState.loading
                    ? loadingChild ?? (const CircleLoader())
                    : child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class CircleLoader extends StatelessWidget {
  const CircleLoader({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);

        return SizedBox(
          width: (defaultTextStyle.style.fontSize ?? 20) / 2,
          height: (defaultTextStyle.style.fontSize ?? 20) / 2,
          // height: 20,
          child: CircularProgressIndicator(
            color: defaultTextStyle.style.color,
          ),
        );
      },
    );
  }
}

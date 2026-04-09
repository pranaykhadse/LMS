import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:lms/app/core/localization/translate.dart';
import 'package:lms/app/core/logic/repository/app_exception.dart';
import 'package:lms/app/core/utils/size_utils.dart';
import 'package:lms/app/core/utils/theme_utils.dart';
import 'package:lms/app/core/views/elements/error/error_toast.dart';

class Toast {
  static void error(
    BuildContext context,
    dynamic error, {
    Duration duration = const Duration(seconds: 10),
    String? title,
  }) {
    showToastWidget(
      Container(
        constraints: const BoxConstraints(
          minHeight: 50,
          maxWidth: 500,
        ),
        child: ErrorToastWidget(
          error: error,
          title: title ?? _errorToTitle(error),
          duration: duration,
        ),
      ),
      duration: duration,
      context: context,
      animation: StyledToastAnimation.slideFromRight,
      reverseAnimation: StyledToastAnimation.fade,
      position:
          const StyledToastPosition(align: Alignment.topRight, offset: 17.0),
    );
  }

  static void errorDialog(
    BuildContext context,
    dynamic error, {
    String? title,
  }) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title ?? _errorToTitle(error)),
        content: Text(error.toString().translate(context)),
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text("ok"),
          ),
        ],
      ),
    );
  }

  static void success(BuildContext context, String message) {
    showToastWidget(
      Container(
        margin: const EdgeInsets.only(right: 20),
        constraints: const BoxConstraints(
          minHeight: 50,
          maxWidth: 500,
        ),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.appColorScheme.success,
          borderRadius: BorderRadius.circular(context.smallRadius),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      context: context,
      animation: StyledToastAnimation.slideFromRight,
      reverseAnimation: StyledToastAnimation.fade,
      position:
          const StyledToastPosition(align: Alignment.topRight, offset: 17.0),
    );
  }
   static Future<void> successDialog(
    BuildContext context,
    dynamic message, {
    Duration duration = const Duration(seconds: 10),
    String? title,
  }) {
   return showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title ?? "Success"),
        content: Text(message.toString().translate(context)),
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text("ok"),
          ),
        ],
      ),
    );
  }
}

String _errorToTitle(error) {
  if (error is AppException) (error).title;
  return "Failed";
}

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
    _showTopToast(
      context: context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      color: const Color(0xFF2E7D32),
    );
  }

  static void info(BuildContext context, String message) {
    _showTopToast(
      context: context,
      message: message,
      icon: Icons.info_outline_rounded,
      color: const Color(0xFF5756C9),
    );
  }

  static void warning(BuildContext context, String message) {
    _showTopToast(
      context: context,
      message: message,
      icon: Icons.warning_amber_rounded,
      color: const Color(0xFFF59E0B),
    );
  }

  /// Red, shield icon, dismissible with an explicit close button - matches
  /// the reference site's "Course has been deleted by the Admin." banner.
  static void danger(BuildContext context, String message) {
    _showTopToast(
      context: context,
      message: message,
      icon: Icons.shield_outlined,
      color: const Color(0xFFDC2626),
      dismissible: true,
      duration: const Duration(seconds: 8),
    );
  }

  static void _showTopToast({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color color,
    Duration duration = const Duration(seconds: 3),
    bool dismissible = false,
  }) {
    showToastWidget(
      SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(color: Color(0x30000000), blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (dismissible) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => dismissAllToast(),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ],
            ],
          ),
        ),
      ),
      context: context,
      duration: duration,
      animation: StyledToastAnimation.slideFromTop,
      reverseAnimation: StyledToastAnimation.slideToTop,
      animDuration: const Duration(milliseconds: 280),
      position: const StyledToastPosition(align: Alignment.topCenter, offset: 0),
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

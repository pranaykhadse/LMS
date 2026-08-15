import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app_module.dart';

/// True when an error message indicates the request failed because the
/// session/token is no longer valid (expired, revoked, etc.), rather than
/// some other kind of failure.
bool isUnauthorizedError(String? error) {
  final v = error?.toLowerCase() ?? '';
  return v.startsWith('unauthorized') ||
      v.contains('invalid credentials') ||
      v.contains('status code of 401') ||
      v.contains(' 401') ||
      v.contains('session expired') ||
      v.contains('session has expired');
}

/// Turns a raw error string into something a user should actually read -
/// the API's own 401 body ("Unauthorized: Your request was made with
/// invalid credentials.") is meaningless to a learner staring at an error
/// screen; this swaps it for a plain explanation of what happened and what
/// to do next. Every other kind of error still shows as-is (falling back to
/// [fallback] if there's no message at all), since those messages are
/// already written to be user-facing.
String friendlyErrorMessage(String? error, String fallback) {
  if (isUnauthorizedError(error)) {
    return 'Your session has expired. Please log in again.';
  }
  return error ?? fallback;
}

/// Logs the user out and sends them back to the login screen, with a
/// "session expired" toast - the shared response to any screen hitting an
/// unauthorized (401) API error. Call from a post-frame callback (the
/// screen calling this is usually still mid-build when it discovers the
/// error) and guard re-entry with a screen-local `bool` flag, since this
/// can otherwise fire once per rebuild while the error state persists.
Future<void> redirectToLoginOnSessionExpired(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Expanded(
            child: Text('Your session has expired. Please log in again.'),
          ),
          IconButton(
            onPressed: messenger.hideCurrentSnackBar,
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      backgroundColor: Colors.redAccent,
      duration: const Duration(days: 365),
    ),
  );
  await ref.read(AuthStateNotifier.provider.notifier).logout();
  messenger.removeCurrentSnackBar();
  Modular.to.navigate(AppModule.auth);
}

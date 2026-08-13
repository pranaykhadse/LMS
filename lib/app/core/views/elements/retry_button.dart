import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';

/// Drop-in replacement for the "Try Again" button every error view uses.
/// Tapping retry when there's genuinely no internet (manual Offline Mode
/// toggle, or no real connection) can only fail again the exact same way,
/// which reads as broken rather than informative - so this shows a plain
/// "you're offline" note instead of the button in that case. Every screen
/// already refetches automatically the moment connectivity returns (see
/// refreshAllOnReconnect), so there's nothing the button would even need to
/// do once back online that doesn't already happen on its own.
///
/// When [errorMessage] indicates the request failed because the session
/// expired (401/unauthorized), this shows "Go To Login" instead - retrying
/// can only fail the exact same way, so the only useful action is to log
/// the user out and send them to the login screen.
class RetryButton extends ConsumerWidget {
  const RetryButton({super.key, required this.onRetry, this.errorMessage});
  final VoidCallback onRetry;
  final String? errorMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isUnauthorizedError(errorMessage)) {
      return HoverBuilder(
        builder: (context, hovering) => ElevatedButton(
          onPressed: () => redirectToLoginOnSessionExpired(context, ref),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                hovering ? FigmaTokens.purpleHover : FigmaTokens.primaryPurple,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          child: const Text('Go To Login', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    final isManualOffline = ref.watch(OfflineModeNotifier.provider);
    final connectionVM = ref.watch(InternetConnectionProvider.provider);
    final isOnline = !isManualOffline && connectionVM.isConnected;
    if (!isOnline) {
      return const Text(
        "You're offline - this will reload automatically once you're "
        'back online.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey, fontSize: 12.5),
      );
    }
    return HoverBuilder(
      builder: (context, hovering) => ElevatedButton(
        onPressed: onRetry,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              hovering ? FigmaTokens.purpleHover : FigmaTokens.primaryPurple,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        child: const Text('Try Again', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

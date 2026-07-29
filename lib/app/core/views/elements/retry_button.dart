import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';

/// Drop-in replacement for the "Try Again" button every error view uses.
/// Tapping retry when there's genuinely no internet (manual Offline Mode
/// toggle, or no real connection) can only fail again the exact same way,
/// which reads as broken rather than informative - so this shows a plain
/// "you're offline" note instead of the button in that case. Every screen
/// already refetches automatically the moment connectivity returns (see
/// refreshAllOnReconnect), so there's nothing the button would even need to
/// do once back online that doesn't already happen on its own.
class RetryButton extends ConsumerWidget {
  const RetryButton({super.key, required this.onRetry, this.style});
  final VoidCallback onRetry;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    return ElevatedButton(
      onPressed: onRetry,
      style: style,
      child: const Text('Try Again', style: TextStyle(color: Colors.white)),
    );
  }
}

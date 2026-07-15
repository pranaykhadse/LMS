import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';

/// Amber banner shown at the top of a page when the app is effectively offline
/// (either the network is gone or the "Go Offline" toggle is ON).
///
/// Tapping it triggers a re-sync attempt. While syncing it shows a spinner.
/// When there are pending completions a count badge is shown.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isManualOffline = ref.watch(OfflineModeNotifier.provider);
    final isConnected = ref.watch(InternetConnectionProvider.provider).isConnected;
    final syncVM = ref.watch(SyncViewModel.provider);

    final bool effectivelyOffline = isManualOffline || !isConnected;
    if (!effectivelyOffline) return const SizedBox.shrink();

    final bool canSync = isConnected && !isManualOffline;
    final int pending = syncVM.pendingCount;

    return GestureDetector(
      onTap: canSync ? () => ref.read(SyncViewModel.provider).sync() : null,
      child: Container(
        width: double.infinity,
        color: Colors.amber.shade700,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Leading icon
            Icon(
              canSync ? Icons.sync_rounded : Icons.cloud_off_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),

            // Message
            Expanded(
              child: Text(
                isManualOffline
                    ? (canSync
                        ? 'Offline Mode ON — tap to re-sync${pending > 0 ? " ($pending pending)" : ""}'
                        : 'Offline Mode ON — no internet available')
                    : (canSync
                        ? 'Currently Offline — tap to re-sync${pending > 0 ? " ($pending pending)" : ""}'
                        : 'You are offline — showing downloaded content'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Spinner while syncing
            if (syncVM.isSyncing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),

            // Pending badge
            if (!syncVM.isSyncing && pending > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pending',
                  style: TextStyle(
                    color: Colors.amber.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

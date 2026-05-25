import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';

/// Switches between [onlineChild] and [offlineChild] based on the
/// *effective* connectivity state.
///
/// The app is considered offline when EITHER:
///   • the physical network is unavailable ([InternetConnectionProvider]), OR
///   • the user has manually toggled "Go Offline" ([OfflineModeNotifier]).
class ConnectionAwareWidget extends ConsumerWidget {
  const ConnectionAwareWidget({
    super.key,
    required this.offlineChild,
    required this.onlineChild,
  });
  final Widget onlineChild;
  final Widget offlineChild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(InternetConnectionProvider.provider);
    final isManualOffline = ref.watch(OfflineModeNotifier.provider);
    final stream = vm.connectionStream;

    return StreamBuilder<bool>(
      stream: stream,
      builder: (context, _) {
        final effectivelyOffline = isManualOffline || !vm.isConnected;
        return effectivelyOffline ? offlineChild : onlineChild;
      },
    );
  }
}

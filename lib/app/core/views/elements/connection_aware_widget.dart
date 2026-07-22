import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';

/// Switches between [onlineChild] and [offlineChild] based on the
/// *effective* connectivity state.
///
/// The app is considered offline when EITHER:
///   • the physical network is unavailable ([InternetConnectionProvider]), OR
///   • the user has manually toggled "Go Offline" ([OfflineModeNotifier]).
///
/// Uses pure Riverpod watchers — no StreamBuilder — so it switches
/// immediately when the offline toggle changes.
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
    // SyncViewModel notifies on physical connection changes so this widget
    // rebuilds whenever real network drops or restores.
    ref.watch(SyncViewModel.provider);

    final effectivelyOffline = isManualOffline || !vm.isConnected;
    return effectivelyOffline ? offlineChild : onlineChild;
  }
}

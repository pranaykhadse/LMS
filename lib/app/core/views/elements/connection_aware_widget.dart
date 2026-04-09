import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';

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
    var vm = ref.watch(InternetConnectionProvider.provider);
    final stream = vm.connectionStream;

    return StreamBuilder(
      stream: stream,
      builder: (context, _) {
        return vm.isConnected ? onlineChild : offlineChild;
      },
    );
  }
}

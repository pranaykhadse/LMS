import 'dart:async';

import 'package:lms/app/core/provider/internet_connection_provider.dart';

mixin OfflineVmHelper {
  StreamSubscription<bool>? _connectionChangeStream;

  InternetConnectionProvider get connectionProvider;
  final List<Future Function()> _callbacks = [];
  bool get isOnline => connectionProvider.isConnected;
  void initDataFetcher() {
    _connectionChangeStream = connectionProvider.connectionStream.listen((
      state,
    ) {
      if (state) {
        for (var item in _callbacks) {
          item.call();
        }
        _callbacks.clear();
      }
    });
  }

  void fetchWhenConnected(Future Function() callback) {
    if (_connectionChangeStream == null) initDataFetcher();
    if (!_callbacks.contains(callback)) {
      _callbacks.add(callback);
    }
  }

  void disposeDataFetcher() {
    _connectionChangeStream?.cancel();
  }
}

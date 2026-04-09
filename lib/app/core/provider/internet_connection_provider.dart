import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:lms/app/core/provider/server_provider.dart';

typedef InternetConnListner = void Function(bool isConnected);

class InternetConnectionProvider {
  static final provider = Provider<InternetConnectionProvider>((ref) {
    return InternetConnectionProvider(ref.watch(ServerProvider.serverUrl));
  });
  final String serverUrl;
  InternetConnectionProvider(this.serverUrl) {
    // intialize();
  }

  late final connection = InternetConnection.createInstance(
    customCheckOptions: [
      InternetCheckOption(
        uri: Uri.parse(
          "${serverUrl}auth", //'https://staging.trainingpipeline.com/api/web/auth'
        ),
      ),
    ],
    useDefaultOptions: false,
    enableStrictCheck: true,
  );
  Future<void> intialize() async {
    // connection.
    final value = await connection.hasInternetAccess;
    _onConnectionChange(value);
    connection.onStatusChange.listen((event) async {
      _onConnectionChange(await connection.hasInternetAccess);
    });
  }

  void _onConnectionChange(bool isConnected) {
    _isConnected = isConnected;
    _controller.add(isConnected);
    for (var listener in _listeners) {
      listener(isConnected);
    }
  }

  final List<InternetConnListner> _listeners = [];
  void addListener(InternetConnListner listener) {
    _listeners.add(listener);
    listener(_isConnected);
  }

  void removeListener(InternetConnListner listener) {
    _listeners.remove(listener);
  }

  bool _isConnected = false;

  bool get isConnected => _isConnected;

  final StreamController<bool> _controller = StreamController<bool>.broadcast(
    sync: true,
  );
  Stream<bool> get connectionStream => _controller.stream;
}

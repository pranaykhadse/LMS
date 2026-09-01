import 'dart:async';

import 'package:flutter/foundation.dart';
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
    intialize();
  }

  late final connection = InternetConnection.createInstance(
    customCheckOptions: [
      // Primary: ping the app's own server so we know it's reachable.
      InternetCheckOption(
        uri: Uri.parse(
          "${serverUrl}auth", //'https://staging.trainingpipeline.com/api/web/auth'
        ),
      ),
      // Fallback: icanhazip.com answers HEAD with 200 and
      // `access-control-allow-origin: *`, so it's readable from a browser
      // too (the auth endpoint 200s on mobile but ships no CORS header,
      // which browser builds can't read). If the app server is down but
      // the device has internet this still returns true, which is correct
      // (a real API error will surface on the login screen rather than the
      // misleading "No Internet" message).
      InternetCheckOption(uri: Uri.parse('https://icanhazip.com')),
    ],
    useDefaultOptions: false,
    // ANY check passing = connected.  With strictCheck=true BOTH would have
    // to pass, meaning a staging outage would make the app look offline.
    enableStrictCheck: false,
  );
  Future<void>? _initializing;

  /// Called from several places (this provider's own constructor, app
  /// startup, and every single AuthGate-wrapped route mount) so it must be
  /// idempotent - it used to re-run its full body every call, which
  /// subscribed a brand new `onStatusChange` listener on every navigation
  /// throughout the app. With dozens of duplicate listeners piling up, each
  /// running its own independent `hasInternetAccess` probe, it only took one
  /// of them observing a transient timing blip to register as a "real"
  /// disconnect/reconnect - which fires refreshAllOnReconnect and silently
  /// wipes out things like an applied Course Catalog search filter on an
  /// otherwise perfectly stable connection. Now the actual check + listener
  /// subscription runs exactly once; later callers just await that same
  /// in-flight/completed future.
  Future<void> intialize() {
    return _initializing ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    // On the web build the unauthenticated cross-origin HEAD probe is
    // CORS-blocked - the auth endpoint responds 200 but without
    // `access-control-allow-origin`, so the browser hides the response and
    // the probe fails, making the app report "No Internet" on every page
    // load despite a live connection. There's no reliable browser-side
    // probe, and real network failures already surface through the actual
    // request errors, so web builds stay online and only the manual
    // "Offline Mode" toggle can force the offline path.
    if (kIsWeb) {
      _onConnectionChange(true);
      return;
    }
    try {
      final value = await connection.hasInternetAccess;
      _onConnectionChange(value);
    } catch (_) {
      _onConnectionChange(false);
    }
    connection.onStatusChange.listen((event) async {
      try {
        final value = await connection.hasInternetAccess;
        _onConnectionChange(value);
      } catch (_) {
        _onConnectionChange(false);
      }
    });
  }

  void _onConnectionChange(bool isConnected) {
    // onStatusChange fires periodically even while connectivity hasn't
    // actually changed (a recurring "still connected" heartbeat, not just
    // real transitions) - notifying listeners on every one of those was
    // triggering SyncViewModel's refreshAllOnReconnect() on a recurring
    // timer instead of only on genuine reconnects, silently wiping out
    // things like an applied Course Catalog search filter while the user
    // was just sitting on an unrelated screen with a perfectly stable
    // connection. Only notify when the status actually flips.
    final changed = _isConnected != isConnected;
    _isConnected = isConnected;
    _controller.add(isConnected);
    if (!changed) return;
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

  // Optimistic default (true = online) rather than false. The first probe
  // runs asynchronously at boot; while it's unresolved every request would
  // otherwise be gated into the offline path - and on the web build that
  // probe is CORS-blocked and frequently reports false even with live
  // internet, making the app look "offline by default" on every page load.
  // Fail-open: assume online until a probe actually proves otherwise.
  bool _isConnected = true;

  bool get isConnected => _isConnected;

  final StreamController<bool> _controller = StreamController<bool>.broadcast(
    sync: true,
  );
  Stream<bool> get connectionStream => _controller.stream;
}

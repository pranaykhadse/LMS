import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/local_storage_provider.dart';

const _kOfflineModeKey = 'offline_mode_enabled';

/// Manages the user-controlled "Go Offline" toggle.
///
/// When [state] is `true` the app behaves as if there is no internet
/// even when a real connection is present.  Persisted to Hive so the
/// preference survives restarts.
class OfflineModeNotifier extends StateNotifier<bool> {
  static final provider =
      StateNotifierProvider<OfflineModeNotifier, bool>((ref) {
    return OfflineModeNotifier(ref.watch(LocalStorage.provider));
  });

  OfflineModeNotifier(this._storage) : super(false) {
    _load();
  }

  final LocalStorage _storage;

  Future<void> _load() async {
    final raw = await _storage.getString(_kOfflineModeKey);
    if (raw == 'true' && mounted) state = true;
  }

  /// Flip the toggle.
  Future<void> toggle() => setMode(!state);

  /// Explicitly set the mode.
  Future<void> setMode(bool value) async {
    state = value;
    await _storage.setString(_kOfflineModeKey, value.toString());
  }
}

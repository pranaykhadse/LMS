import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/logic/vm_helper/offline_vm_helper.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/local_storage_provider.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/authentication/repository/auth_repository.dart';
import 'package:lms/app/features/courses/repository/sync_queue_repository.dart';

import '../model/auth_state.dart';

class AuthStateNotifier extends StateNotifier<AuthState?> with OfflineVmHelper {
  static final provider = StateNotifierProvider<AuthStateNotifier, AuthState?>((
    ref,
  ) {
    return AuthStateNotifier(
      baseUrl: ref.watch(ServerProvider.serverUrl),
      storage: ref.watch(LocalStorage.provider),
      connectionProvider: ref.watch(InternetConnectionProvider.provider),
      syncQueueRepo: ref.watch(SyncQueueRepository.provider),
    );
  });

  AuthStateNotifier({
    required this.baseUrl,
    required this.storage,
    required this.connectionProvider,
    required this.syncQueueRepo,
  }) : super(null);
  final String baseUrl;
  final LocalStorage storage;
  final SyncQueueRepository syncQueueRepo;
  @override
  final InternetConnectionProvider connectionProvider;

  @override
  bool get isOnline => connectionProvider.isConnected;

  Future<void> login({required String email, required String password}) async {
    if (!isOnline) {
      final sessionDataRaw = await storage.getString("session_data");
      if (sessionDataRaw != null) {
        try {
          final data = jsonDecode(sessionDataRaw);
          final sessionData = AuthState.fromRawJson(data);
          state = sessionData;
        } catch (e) {}
        return;
      }
    }
    final repo = AuthRepository(
      config: RepoNetworkConfig(
        url: baseUrl,
        connectionProvider: connectionProvider,
      ),
    );

    final sessionData = await repo.loginWithEmail(
      email: email,
      password: password,
    );

    await storage.setString("session_data", sessionData.toRawJson());
    if (!mounted) return;
    state = sessionData;
  }

  /// Keeps the cached profile - used app-wide, e.g. the app bar avatar -
  /// in sync with edits made from Account Settings. AccountSettingsViewModel
  /// has its own separate profile state for that screen; without also
  /// pushing the update here, everywhere else reading
  /// AuthStateNotifier.provider (the app bar, etc.) kept showing whatever
  /// was cached at login until the next full login. Persists to storage
  /// too, so a cold restart restores the updated profile rather than the
  /// stale one from the last real login.
  Future<void> updateProfile(UserProfile profile) async {
    if (kDebugMode) debugPrint('[AuthStateNotifier.updateProfile] CALLED');
    final current = state;
    if (current == null) return;
    // UserProfile has no ==/hashCode, so copyWith always produces a "new"
    // AuthState by identity even when nothing actually changed - and
    // AccountSettingsViewModel.fetch() calls this on every load, not just
    // after a real edit. Something downstream (even after switching every
    // known ref.watch on AuthStateNotifier to ref.read - see
    // account_settings_view_model.dart) still ends up rebuilding
    // AccountSettingsViewModel.provider every time this state is replaced,
    // which calls fetch() again, which calls this again - forever. Skipping
    // the replacement when the profile is already identical breaks that
    // cycle at the root regardless of which exact dependency causes the
    // rebuild.
    if (_sameProfile(current.userProfile, profile)) {
      if (kDebugMode) debugPrint('[AuthStateNotifier.updateProfile] SKIPPED - profile unchanged');
      return;
    }
    final updated = current.copyWith(userProfile: profile);
    state = updated;
    if (kDebugMode) debugPrint('[AuthStateNotifier.updateProfile] state REPLACED (new AuthState instance)');
    await storage.setString("session_data", updated.toRawJson());
  }

  bool _sameProfile(UserProfile? a, UserProfile b) {
    if (a == null) return false;
    return a.avatarPath == b.avatarPath &&
        a.avatarBaseUrl == b.avatarBaseUrl &&
        a.firstname == b.firstname &&
        a.lastname == b.lastname &&
        a.location == b.location &&
        a.website == b.website &&
        a.linkedIn == b.linkedIn &&
        a.division == b.division &&
        a.department == b.department;
  }

  Future<void> logout() async {
    await storage.setString("session_data", null);
    // Clear any queued offline completions so they don't bleed into the
    // next user's session.
    await syncQueueRepo.clear();
    // Downloaded course content (videos/PDFs/HLS) is intentionally left in
    // place - it must survive logout/login for the same user, so offline
    // courses keep working exactly as they did when the user downloaded
    // them while online.
    state = null;
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initCompleter => _initCompleter.future;
  Future<void> initialize() async {
    if (state != null) return;
    final tokenData = await storage.getString("session_data");
    if (tokenData != null) {
      final token = AuthState.fromRawJson(tokenData);

      if (isOnline) {
        await _validateCurrentToken(token);
      } else {
        state = token;
        fetchWhenConnected(() => _validateCurrentToken(token));
      }
    }

    _isInitialized = true;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
  }

  Future<void> _validateCurrentToken(AuthState token) async {
    try {
      await AuthRepository(
        config: RepoNetworkConfig(
          url: baseUrl,
          connectionProvider: connectionProvider,
          authToken: token.token,
        ),
      ).validateToken(token);
      if (!mounted) return;
      state = token;
    } catch (e) {
      log("VALidate auth token error: $e");
    }
  }
}

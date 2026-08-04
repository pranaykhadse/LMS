import 'dart:async';
import 'dart:convert';
import 'dart:developer';

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
  /// was cached at login until the next full login.
  Future<void> updateProfile(UserProfile profile) async {
    final current = state;
    if (current == null) return;
    final updated = current.copyWith(userProfile: profile);
    state = updated;
    await storage.setString("session_data", updated.toRawJson());
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

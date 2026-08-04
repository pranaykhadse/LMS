import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/dashboard/model/user_profile_detail.dart';
import 'package:lms/app/features/dashboard/repository/account_settings_repository.dart';

class AccountSettingsViewModel
    extends StateNotifier<DataState<UserProfileDetail>> {
  AccountSettingsViewModel({
    required this.repository,
    required this.userId,
    required this.ref,
  }) : super(DataState.idle<UserProfileDetail>()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
      AccountSettingsViewModel, DataState<UserProfileDetail>>((ref) {
    final userId = ref.watch(AuthStateNotifier.provider)?.user?.id;
    return AccountSettingsViewModel(
      repository: ref.watch(AccountSettingsRepository.provider),
      userId: userId,
      ref: ref,
    );
  });

  final AccountSettingsRepository repository;
  final int? userId;
  final Ref ref;

  Future<void> fetch() async {
    if (kDebugMode) debugPrint('[AccountSettingsViewModel.fetch] CALLED, userId=$userId');
    if (userId == null) {
      if (kDebugMode) debugPrint('[AccountSettingsViewModel.fetch] SKIPPED - userId is null');
      state = DataState.onError('User not logged in.');
      return;
    }
    state = DataState.loading<UserProfileDetail>();
    try {
      if (kDebugMode) debugPrint('[AccountSettingsViewModel.fetch] calling repository.fetch()...');
      final data = await repository.fetch(userId: userId!);
      if (kDebugMode) debugPrint('[AccountSettingsViewModel.fetch] repository.fetch() SUCCEEDED');
      if (mounted) state = DataState.onData(data);
      // This is the authoritative, always-fresh profile straight from the
      // server - sync it into the app-wide cached profile every time this
      // screen loads, not just after an explicit edit. Without this, a
      // change made (and correctly synced) in one app session wouldn't
      // show up in the app bar on the *next* cold start, since
      // AuthStateNotifier.initialize() just restores whatever was last
      // persisted rather than refetching. Kept outside the `mounted` check
      // above - AuthStateNotifier is a different, kept-alive notifier, so
      // this sync should still happen even if this screen's own state is
      // now moot.
      await ref.read(AuthStateNotifier.provider.notifier).updateProfile(data.profile);
    } catch (e) {
      if (kDebugMode) debugPrint('[AccountSettingsViewModel.fetch] repository.fetch() FAILED: $e');
      if (!mounted) return;
      state = DataState.onError(_friendly(e));
    }
  }

  /// Saves edits made from Account Settings. Returns an error message on
  /// failure, or null on success (after which local state reflects the
  /// edited values immediately — no need to wait on a re-fetch).
  Future<String?> update({
    required String firstname,
    required String lastname,
    required String location,
    required String website,
    required String linkedIn,
    required String division,
    required String department,
    String? avatarUrl,
    String? phoneNumber,
  }) async {
    final current = state.data;
    if (userId == null || current == null) {
      return 'Unable to save — profile not loaded.';
    }
    final body = current.profile.toUpdateJson(
      firstname: firstname,
      lastname: lastname,
      location: location,
      website: website,
      linkedIn: linkedIn,
      division: division,
      department: department,
      avatarPath: avatarUrl,
    );
    // Not part of the documented PUT schema — included as a best-effort
    // guess (it's the key the GET response returns this value under).
    if (phoneNumber != null) body['phone_number'] = phoneNumber;
    final result = await repository.update(userId: userId!, body: body);
    if (!result.success) {
      return result.message ?? 'Unable to save your changes. Please try again.';
    }
    final updatedProfile = current.profile.copyWith(
      firstname: firstname,
      lastname: lastname,
      location: location,
      website: website,
      linkedIn: linkedIn,
      division: division,
      department: department,
      avatarPath: avatarUrl,
    );
    if (mounted) {
      state = DataState.onData(
        UserProfileDetail(
          profile: updatedProfile,
          user: current.user,
          phoneNumber: phoneNumber ?? current.phoneNumber,
          enableTextMessages: current.enableTextMessages,
        ),
      );
    }
    // Keep the app-wide cached profile (app bar name/avatar, etc.) in sync
    // - this screen's own state above isn't visible anywhere else, and
    // AuthStateNotifier is a different, kept-alive notifier, so this
    // should still run even if this screen's own state is now moot.
    await ref.read(AuthStateNotifier.provider.notifier).updateProfile(updatedProfile);
    return null;
  }

  /// Uploads a new avatar via POST user-profile/upload-avatar, then
  /// refetches the full profile rather than guessing at the upload
  /// response's shape - the plain GET already reliably returns the new
  /// avatar_path/avatar_base_url pair (fetch() also syncs it into the
  /// app-wide cached profile). Returns an error message on failure, or
  /// null on success.
  Future<String?> uploadAvatar(Uint8List bytes, String filename) async {
    if (userId == null) return 'Unable to upload avatar — not logged in.';
    final result = await repository.uploadAvatar(bytes: bytes, filename: filename);
    if (!result.success) {
      return result.message ?? 'Unable to upload avatar. Please try again.';
    }
    await fetch();
    return null;
  }

  /// Changes the logged-in user's password. Returns an error message on
  /// failure, or null on success.
  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (userId == null) return 'Unable to change password — not logged in.';
    final result = await repository.changePassword(
      userId: userId!,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    return result.success
        ? null
        : (result.message ?? 'Unable to change password. Please try again.');
  }

  String _friendly(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Session expired. Please log in again.';
    }
    if (msg.contains('SocketException') || msg.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    return 'Unable to load your profile. Please try again.';
  }
}

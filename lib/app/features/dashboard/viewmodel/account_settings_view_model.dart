import 'dart:typed_data';

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
    AccountSettingsViewModel,
    DataState<UserProfileDetail>
  >((ref) {
    // ref.read everywhere here, not ref.watch: fetch() below calls
    // AuthStateNotifier.updateProfile(), which changes AuthStateNotifier's
    // state - and AccountSettingsRepository.provider transitively depends
    // on AuthStateNotifier too (via ServerProvider.repoConfigProvider's
    // authToken: ref.watch(AuthStateNotifier.provider)?.token). Watching
    // *either* one here rebuilds this provider every time updateProfile()
    // runs - tearing down and recreating AccountSettingsViewModel, whose
    // constructor calls fetch() again, which calls updateProfile() again,
    // forever. Only the values at construction time are needed here, not
    // live updates to either.
    final userId = ref.read(AuthStateNotifier.provider)?.user?.id;
    return AccountSettingsViewModel(
      repository: ref.read(AccountSettingsRepository.provider),
      userId: userId,
      ref: ref,
    );
  });

  final AccountSettingsRepository repository;
  final int? userId;
  final Ref ref;

  Future<void> fetch() async {
    if (userId == null) {
      state = DataState.onError('User not logged in.');
      return;
    }
    // Keep whatever's already on screen while refetching instead of
    // flashing back to a full-screen spinner - only show it on the very
    // first load, when there's nothing to keep showing yet. Without this,
    // every refresh (including the one uploadAvatar() triggers right after
    // a successful upload) briefly blanked the whole screen and popped it
    // back, even though the data underneath barely changed.
    final hasData = state.state == DataProviderState.data;
    if (!hasData) state = DataState.loading<UserProfileDetail>();
    try {
      final data = await repository.fetch(userId: userId!);
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
      await ref
          .read(AuthStateNotifier.provider.notifier)
          .updateProfile(data.profile);
    } catch (e) {
      if (!mounted) return;
      // On a background refresh (data already showing), leave it in place
      // rather than replacing it with a full-screen error - only show the
      // error state if there was nothing on screen to begin with.
      if (!hasData) state = DataState.onError(_friendly(e));
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
    String? countryCode,
    String? countryIso,
    // API ref: PUT /api/web/user-profile/{id}'s own docs - "Beyond the
    // plain profile fields below, also accepts email, state_id, cost_code,
    // supervisor_name/supervisor_email, primary_group_id(+type/main_id)
    // and enable_two_factor_auth, which update tbl_user/tbl_user_group
    // instead of tbl_user_profile." These were previously flagged as
    // disabled (no update path) - confirmed newly available via that
    // Swagger doc.
    String? email,
    String? costCode,
    String? supervisorName,
    String? supervisorEmail,
    int? primaryGroupId,
    bool? enableTwoFactorAuth,
    // state_id comes straight from the StateOption the user picked in
    // account_settings_page.dart's state picker (see country_states_data.dart
    // for the full id table, sourced from the real web app's live State
    // dropdown HTML - every country, not just the US). stateName is passed
    // alongside purely so it can be synced into AuthState's own stateName
    // display field without this viewmodel needing to import the view's
    // data back.
    int? stateId,
    String? stateName,
    // notification_type/text_phone_number/whatsapp_phone_number/
    // email_options/slack_email/teams_email are all `UserProfile` "safe"
    // attributes (common/models/UserProfile.php) - the same mass-
    // assignable set the base profile fields above already go through.
    // The PHP source marks the whole Notification Type block
    // `disabled=true readonly=true`, but a live screenshot showed it's
    // actually editable - see account_settings_page.dart's Notification
    // Type section comment for that evidence.
    String? notificationType,
    String? textPhoneNumber,
    String? whatsappPhoneNumber,
    String? emailOptions,
    String? slackEmail,
    String? teamsEmail,
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
      countryCode: countryCode,
      countryIso: countryIso,
    );
    // Not part of the documented PUT schema — included as a best-effort
    // guess (it's the key the GET response returns this value under).
    if (phoneNumber != null) body['phone_number'] = phoneNumber;
    if (email != null) body['email'] = email;
    if (costCode != null) body['cost_code'] = costCode;
    if (supervisorName != null) body['supervisor_name'] = supervisorName;
    if (supervisorEmail != null) body['supervisor_email'] = supervisorEmail;
    if (primaryGroupId != null) {
      body['primary_group_id'] = primaryGroupId;
      // Swagger's own example pairs primary_group_id with a matching
      // primary_group_main_id and a literal "single_group" type - no
      // other type value is documented anywhere, so this is the only
      // shape confirmed to work.
      body['primary_group_type'] = 'single_group';
      body['primary_group_main_id'] = primaryGroupId;
    }
    if (enableTwoFactorAuth != null) {
      body['enable_two_factor_auth'] = enableTwoFactorAuth;
    }
    if (stateId != null) body['state_id'] = stateId;
    if (notificationType != null) body['notification_type'] = notificationType;
    if (textPhoneNumber != null) body['text_phone_number'] = textPhoneNumber;
    if (whatsappPhoneNumber != null) {
      body['whatsapp_phone_number'] = whatsappPhoneNumber;
    }
    if (emailOptions != null) body['email_options'] = emailOptions;
    if (slackEmail != null) body['slack_email'] = slackEmail;
    if (teamsEmail != null) body['teams_email'] = teamsEmail;
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
      countryCode: countryCode,
      countryIso: countryIso,
      notificationType: notificationType,
      textPhoneNumber: textPhoneNumber,
      whatsappPhoneNumber: whatsappPhoneNumber,
      emailOptions: emailOptions,
      slackEmail: slackEmail,
      teamsEmail: teamsEmail,
    );
    final updatedUser = current.user.copyWith(
      email: email,
      costCode: costCode,
      primaryGroup: primaryGroupId,
      enableTwoFactorAuth:
          enableTwoFactorAuth == null ? null : (enableTwoFactorAuth ? 1 : 0),
    );
    if (mounted) {
      state = DataState.onData(
        UserProfileDetail(
          profile: updatedProfile,
          user: updatedUser,
          phoneNumber: phoneNumber ?? current.phoneNumber,
          enableTextMessages: current.enableTextMessages,
        ),
      );
    }
    // Keep the app-wide cached profile (app bar name/avatar, etc.) in sync
    // - this screen's own state above isn't visible anywhere else, and
    // AuthStateNotifier is a different, kept-alive notifier, so this
    // should still run even if this screen's own state is now moot.
    await ref
        .read(AuthStateNotifier.provider.notifier)
        .updateProfile(updatedProfile);
    await ref
        .read(AuthStateNotifier.provider.notifier)
        .updateAccountExtras(
          email: email,
          costCode: costCode,
          supervisorName: supervisorName,
          supervisorEmail: supervisorEmail,
          primaryGroupId: primaryGroupId,
          enableTwoFactorAuth: enableTwoFactorAuth,
          stateId: stateId,
          stateName: stateName,
        );
    return null;
  }

  /// Flips "Receive Text Message Reminders" immediately on toggle, outside
  /// the Edit/Save flow - same immediate-save pattern as [uploadAvatar].
  /// enable_text_messages isn't part of the documented PUT schema either
  /// (same caveat as phone_number in [update]) - included as a best-effort
  /// guess matching the key the GET response returns this value under.
  Future<String?> setEnableTextMessages(bool value) async {
    final current = state.data;
    if (userId == null || current == null) {
      return 'Unable to save — profile not loaded.';
    }
    final body = current.profile.toUpdateJson();
    body['enable_text_messages'] = value ? 1 : 0;
    final result = await repository.update(userId: userId!, body: body);
    if (!result.success) {
      return result.message ?? 'Unable to update reminders. Please try again.';
    }
    if (mounted) {
      state = DataState.onData(
        UserProfileDetail(
          profile: current.profile,
          user: current.user,
          phoneNumber: current.phoneNumber,
          enableTextMessages: value,
        ),
      );
    }
    return null;
  }

  /// Uploads a new avatar via POST user-profile/upload-avatar, then patches
  /// just the avatar_path/avatar_base_url the upload response itself
  /// returns onto the profile already in state - deliberately not a full
  /// fetch()/replace, which would swap in a brand new UserProfileDetail
  /// object and risk every other field on screen (name, location, etc.)
  /// visibly refreshing along with the avatar. Returns an error message on
  /// failure, or null on success.
  Future<String?> uploadAvatar(Uint8List bytes, String filename) async {
    if (userId == null) return 'Unable to upload avatar — not logged in.';
    final result = await repository.uploadAvatar(
      bytes: bytes,
      filename: filename,
    );
    if (!result.success) {
      return result.message ?? 'Unable to upload avatar. Please try again.';
    }
    final current = state.data;
    if (current != null && result.avatarPath != null) {
      final patchedProfile = current.profile.copyWith(
        avatarPath: result.avatarPath,
        avatarBaseUrl: result.avatarBaseUrl,
      );
      if (mounted) {
        state = DataState.onData(
          UserProfileDetail(
            profile: patchedProfile,
            user: current.user,
            phoneNumber: current.phoneNumber,
            enableTextMessages: current.enableTextMessages,
          ),
        );
      }
      await ref
          .read(AuthStateNotifier.provider.notifier)
          .updateProfile(patchedProfile);
    }
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

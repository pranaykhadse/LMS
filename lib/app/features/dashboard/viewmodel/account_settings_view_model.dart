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
  }) : super(DataState.idle<UserProfileDetail>()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
      AccountSettingsViewModel, DataState<UserProfileDetail>>((ref) {
    final userId = ref.watch(AuthStateNotifier.provider)?.user?.id;
    return AccountSettingsViewModel(
      repository: ref.watch(AccountSettingsRepository.provider),
      userId: userId,
    );
  });

  final AccountSettingsRepository repository;
  final int? userId;

  Future<void> fetch() async {
    if (userId == null) {
      state = DataState.onError('User not logged in.');
      return;
    }
    state = DataState.loading<UserProfileDetail>();
    try {
      final data = await repository.fetch(userId: userId!);
      state = DataState.onData(data);
    } catch (e) {
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
    );
    final result = await repository.update(userId: userId!, body: body);
    if (!result.success) {
      return result.message ?? 'Unable to save your changes. Please try again.';
    }
    state = DataState.onData(
      UserProfileDetail(
        profile: current.profile.copyWith(
          firstname: firstname,
          lastname: lastname,
          location: location,
          website: website,
          linkedIn: linkedIn,
          division: division,
          department: department,
        ),
        user: current.user,
        phoneNumber: current.phoneNumber,
        enableTextMessages: current.enableTextMessages,
      ),
    );
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

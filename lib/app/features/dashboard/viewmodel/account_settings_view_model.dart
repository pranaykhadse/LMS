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

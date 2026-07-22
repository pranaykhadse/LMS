import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/repository/dashboard_repository.dart';

class DashboardViewModel extends StateNotifier<DataState<DashboardResponse>> {
  DashboardViewModel({required this.repository, required this.userId})
    : super(DataState.idle<DashboardResponse>()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
    DashboardViewModel,
    DataState<DashboardResponse>
  >((ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    return DashboardViewModel(
      repository: ref.watch(DashboardRepository.provider),
      userId: _loggedInUserId(auth),
    );
  });

  final DashboardRepository repository;
  final int? userId;

  Future<void> fetch() async {
    if (userId == null) {
      state = DataState.onError('The logged-in user ID is unavailable.');
      return;
    }
    state = DataState.loading<DashboardResponse>();
    try {
      final result = await repository.fetch(userId: userId!);
      state = DataState.onData(result);
    } catch (error) {
      state = DataState.onError(error.toString());
    }
  }
}

int? _loggedInUserId(AuthState? auth) {
  return auth?.userProfile?.userId ?? auth?.user?.id;
}

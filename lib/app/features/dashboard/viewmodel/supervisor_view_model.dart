import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import '../model/mentor_modal.dart';
import '../repository/mentor_repository.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';

class SupervisorViewModel extends StateNotifier<DataState<MentorModalData?>> {
  SupervisorViewModel({required this.repository, required this.userId})
      : super(DataState.idle<MentorModalData?>());

  // Not autoDispose: nothing in the widget tree ref.watch()s this provider
  // (only bare ref.read() calls from the one-time dashboard fetch flow),
  // so with autoDispose the provider could be torn down and recreated
  // (resetting to idle/null data) between the fetch completing and the
  // flow reading its result back out - the fetched supervisor data must
  // survive for the whole app session, matching the "once per session"
  // fetch semantics this is meant to have.
  static final provider = StateNotifierProvider<SupervisorViewModel, DataState<MentorModalData?>>((ref) {
    final userId = ref.watch(AuthStateNotifier.provider)?.user?.id;
    return SupervisorViewModel(
      repository: ref.watch(MentorRepository.provider),
      userId: userId,
    );
  });

  final MentorRepository repository;
  final int? userId;

  Future<void> fetchIfNeeded() async {
    if (state.state == DataProviderState.data || state.state == DataProviderState.loading) {
      if (kDebugMode) debugPrint('[SupervisorViewModel] fetchIfNeeded skipped - state=${state.state}');
      return;
    }
    if (userId == null) {
      if (kDebugMode) debugPrint('[SupervisorViewModel] fetchIfNeeded skipped - userId is null');
      return;
    }

    if (kDebugMode) debugPrint('[SupervisorViewModel] fetchIfNeeded starting for userId=$userId');
    state = DataState.loading<MentorModalData?>();
    try {
      final data = await repository.fetch(userId: userId!, type: 'supervisor');
      if (kDebugMode) debugPrint('[SupervisorViewModel] fetched data: ${data.toString()}');
      if (!mounted) return;
      state = DataState.onData(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[SupervisorViewModel] fetch error: ${e.toString()}');
      if (!mounted) return;
      state = DataState.onError(e.toString());
    }
  }
}

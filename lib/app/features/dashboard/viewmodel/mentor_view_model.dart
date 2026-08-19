import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import '../model/mentor_modal.dart';
import '../repository/mentor_repository.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';

class MentorViewModel extends StateNotifier<DataState<MentorModalData?>> {
  MentorViewModel({required this.repository, required this.userId})
      : super(DataState.idle<MentorModalData?>());

  // Not autoDispose: nothing in the widget tree ref.watch()s this provider
  // (only bare ref.read() calls from the one-time dashboard fetch flow),
  // so with autoDispose the provider could be torn down and recreated
  // (resetting to idle/null data) between the fetch completing and the
  // flow reading its result back out - the fetched mentor data must
  // survive for the whole app session, matching the "once per session"
  // fetch semantics this is meant to have.
  static final provider = StateNotifierProvider<MentorViewModel, DataState<MentorModalData?>>((ref) {
    final userId = ref.watch(AuthStateNotifier.provider)?.user?.id;
    return MentorViewModel(
      repository: ref.watch(MentorRepository.provider),
      userId: userId,
    );
  });

  final MentorRepository repository;
  final int? userId;

  /// Fetch only if not already fetched and user is present.
  Future<void> fetchIfNeeded() async {
    // If we already have data or are loading, do nothing
    if (state.state == DataProviderState.data || state.state == DataProviderState.loading) {
      print('[MentorViewModel] fetchIfNeeded skipped - state=${state.state}');
      if (kDebugMode) debugPrint('[MentorViewModel] fetchIfNeeded skipped - state=${state.state}');
      return;
    }
    if (userId == null) {
      print('[MentorViewModel] fetchIfNeeded skipped - userId is null');
      if (kDebugMode) debugPrint('[MentorViewModel] fetchIfNeeded skipped - userId is null');
      return;
    }

    print('[MentorViewModel] fetchIfNeeded starting for userId=$userId');
    if (kDebugMode) debugPrint('[MentorViewModel] fetchIfNeeded starting for userId=$userId');
    state = DataState.loading<MentorModalData?>();
    try {
      final data = await repository.fetch(userId: userId!);
      print('[MentorViewModel] fetched data: ${data.toString()}');
      if (kDebugMode) debugPrint('[MentorViewModel] fetched data: ${data.toString()}');
      if (!mounted) return;
      state = DataState.onData(data);
    } catch (e) {
      print('[MentorViewModel] fetch error: ${e.toString()}');
      if (kDebugMode) debugPrint('[MentorViewModel] fetch error: ${e.toString()}');
      if (!mounted) return;
      state = DataState.onError(e.toString());
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/dashboard/model/learning_progress_model.dart';
import 'package:lms/app/features/dashboard/repository/learning_progress_repository.dart';

class LearningProgressViewModel
    extends StateNotifier<DataState<LearningProgressData>> {
  LearningProgressViewModel({
    required this.repository,
    required this.userId,
  }) : super(DataState.idle<LearningProgressData>()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
      LearningProgressViewModel, DataState<LearningProgressData>>((ref) {
    final userId = ref.watch(AuthStateNotifier.provider)?.user?.id;
    return LearningProgressViewModel(
      repository: ref.watch(LearningProgressRepository.provider),
      userId: userId,
    );
  });

  final LearningProgressRepository repository;
  final int? userId;

  Future<void> fetch() async {
    if (userId == null) {
      state = DataState.onError('User not logged in.');
      return;
    }
    state = DataState.loading<LearningProgressData>();
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
    return 'Unable to load progress. Please try again.';
  }
}

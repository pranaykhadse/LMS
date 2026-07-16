import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/dashboard/model/learning_path.dart';
import 'package:lms/app/features/dashboard/repository/learning_paths_repository.dart';

class LearningPathsState {
  const LearningPathsState({
    this.providerState = DataProviderState.idle,
    this.paths = const [],
    this.error,
  });

  final DataProviderState providerState;
  final List<LearningPath> paths;
  final String? error;

  LearningPathsState copyWith({
    DataProviderState? providerState,
    List<LearningPath>? paths,
    String? error,
  }) => LearningPathsState(
    providerState: providerState ?? this.providerState,
    paths: paths ?? this.paths,
    error: error,
  );
}

class LearningPathsViewModel extends StateNotifier<LearningPathsState> {
  LearningPathsViewModel({required this.repository, required this.userId})
    : super(const LearningPathsState()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
    LearningPathsViewModel,
    LearningPathsState
  >((ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    return LearningPathsViewModel(
      repository: ref.watch(LearningPathsRepository.provider),
      userId: _loggedInUserId(auth),
    );
  });

  final LearningPathsRepository repository;
  final int? userId;

  Future<void> fetch({String? name}) async {
    if (userId == null) {
      state = state.copyWith(
        providerState: DataProviderState.error,
        error: 'The logged-in user ID is unavailable.',
      );
      return;
    }
    state = state.copyWith(providerState: DataProviderState.loading);
    try {
      final paths = await repository.fetch(userId: userId!, name: name);
      state = state.copyWith(
        providerState: DataProviderState.data,
        paths: paths,
      );
    } catch (error) {
      state = state.copyWith(
        providerState: DataProviderState.error,
        error: error.toString(),
      );
    }
  }
}

int? _loggedInUserId(AuthState? auth) =>
    auth?.userProfile?.userId ?? auth?.user?.id;

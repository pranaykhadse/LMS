import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/dashboard/model/view_competency.dart';
import 'package:lms/app/features/dashboard/repository/view_competency_repository.dart';

class ViewCompetencyArgs {
  const ViewCompetencyArgs({
    required this.learningPathId,
    required this.competency,
  });

  final int learningPathId;
  final String competency;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ViewCompetencyArgs &&
          other.learningPathId == learningPathId &&
          other.competency == competency);

  @override
  int get hashCode => Object.hash(learningPathId, competency);
}

class ViewCompetencyViewModel
    extends StateNotifier<DataState<ViewCompetencyResult>> {
  ViewCompetencyViewModel({
    required this.repository,
    required this.userId,
    required this.args,
  }) : super(DataState.idle<ViewCompetencyResult>()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose.family<
      ViewCompetencyViewModel,
      DataState<ViewCompetencyResult>,
      ViewCompetencyArgs>((ref, args) {
    final auth = ref.watch(AuthStateNotifier.provider);
    return ViewCompetencyViewModel(
      repository: ref.watch(ViewCompetencyRepository.provider),
      userId: _loggedInUserId(auth),
      args: args,
    );
  });

  final ViewCompetencyRepository repository;
  final int? userId;
  final ViewCompetencyArgs args;

  Future<void> fetch() async {
    if (userId == null) {
      state = DataState.onError('The logged-in user ID is unavailable.');
      return;
    }
    state = DataState.loading<ViewCompetencyResult>();
    try {
      final data = await repository.fetch(
        userId: userId!,
        learningPathId: args.learningPathId,
        competency: args.competency,
      );
      if (!mounted) return;
      state = DataState.onData(data);
    } catch (e) {
      if (!mounted) return;
      state = DataState.onError(e.toString());
    }
  }
}

int? _loggedInUserId(AuthState? auth) =>
    auth?.userProfile?.userId ?? auth?.user?.id;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/model/course_catalog.dart';
import 'package:lms/app/features/courses/repository/course_catalog_repository.dart';

class CourseCatalogState {
  const CourseCatalogState({
    required this.result,
    this.search = '',
    this.skillId,
  });

  factory CourseCatalogState.initial() => CourseCatalogState(
        result: DataState.idle<CourseCatalogResponse>(),
      );

  final DataState<CourseCatalogResponse> result;
  final String search;
  final String? skillId;

  CourseCatalogState copyWith({
    DataState<CourseCatalogResponse>? result,
    String? search,
    String? skillId,
    bool clearSkill = false,
  }) {
    return CourseCatalogState(
      result: result ?? this.result,
      search: search ?? this.search,
      skillId: clearSkill ? null : (skillId ?? this.skillId),
    );
  }
}

class CourseCatalogViewModel extends StateNotifier<CourseCatalogState> {
  CourseCatalogViewModel({
    required this.repository,
    required this.userId,
  }) : super(CourseCatalogState.initial()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
      CourseCatalogViewModel, CourseCatalogState>((ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    return CourseCatalogViewModel(
      repository: ref.watch(CourseCatalogRepository.provider),
      userId: auth?.user?.id ?? auth?.userProfile?.userId,
    );
  });

  final CourseCatalogRepository repository;
  final int? userId;

  Future<void> fetch({int page = 1}) async {
    if (userId == null) {
      state = state.copyWith(
        result: DataState.onError('The logged-in user ID is unavailable.'),
      );
      return;
    }
    state = state.copyWith(result: DataState.loading<CourseCatalogResponse>());
    try {
      final result = await repository.fetch(
        userId: userId!,
        page: page,
        search: state.search,
        skillId: state.skillId,
      );
      state = state.copyWith(result: DataState.onData(result));
    } catch (error) {
      state = state.copyWith(result: DataState.onError(error.toString()));
    }
  }

  Future<void> applyFilters({required String search, String? skillId}) async {
    state = state.copyWith(
      search: search,
      skillId: skillId,
      clearSkill: skillId == null,
    );
    await fetch();
  }

  Future<void> reset() async {
    state = CourseCatalogState.initial();
    await fetch();
  }
}

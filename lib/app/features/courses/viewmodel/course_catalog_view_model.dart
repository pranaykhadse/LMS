import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/courses/model/course_catalog.dart';
import 'package:lms/app/features/courses/repository/course_catalog_repository.dart';

class CourseCatalogState {
  const CourseCatalogState({
    required this.result,
    this.search = '',
    this.skillId,
    this.behaviorId,
    this.isSearchMode = false,
    this.filterOptions = const [],
    this.page = 1,
    this.groupPages = const {},
  });

  factory CourseCatalogState.initial() =>
      CourseCatalogState(result: DataState.idle<CourseCatalogResponse>());

  final DataState<CourseCatalogResponse> result;
  final String search;
  final String? skillId;
  final String? behaviorId;
  final bool isSearchMode;
  final List<CatalogSkill> filterOptions;
  final int page;
  final Map<String, int> groupPages;

  CourseCatalogState copyWith({
    DataState<CourseCatalogResponse>? result,
    String? search,
    String? skillId,
    String? behaviorId,
    bool? isSearchMode,
    List<CatalogSkill>? filterOptions,
    int? page,
    Map<String, int>? groupPages,
    bool clearSkill = false,
    bool clearBehavior = false,
  }) {
    return CourseCatalogState(
      result: result ?? this.result,
      search: search ?? this.search,
      skillId: clearSkill ? null : (skillId ?? this.skillId),
      behaviorId: clearBehavior ? null : (behaviorId ?? this.behaviorId),
      isSearchMode: isSearchMode ?? this.isSearchMode,
      filterOptions: filterOptions ?? this.filterOptions,
      page: page ?? this.page,
      groupPages: groupPages ?? this.groupPages,
    );
  }
}

class CourseCatalogViewModel extends StateNotifier<CourseCatalogState> {
  CourseCatalogViewModel({required this.repository, required this.userId})
    : super(CourseCatalogState.initial()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
    CourseCatalogViewModel,
    CourseCatalogState
  >((ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    return CourseCatalogViewModel(
      repository: ref.watch(CourseCatalogRepository.provider),
      userId: _loggedInUserId(auth),
    );
  });

  final CourseCatalogRepository repository;
  final int? userId;

  Future<String?> fetch({Map<String, int>? groupPages}) async {
    if (userId == null) {
      const message = 'The logged-in user ID is unavailable.';
      state = state.copyWith(result: DataState.onError(message));
      return message;
    }
    final pages = groupPages ?? state.groupPages;
    // Keep whatever is already on screen while a page/filter change is in
    // flight instead of flashing back to a full-screen spinner.
    final hasData = state.result.state == DataProviderState.data;
    if (!hasData) {
      state = state.copyWith(
        result: DataState.loading<CourseCatalogResponse>(),
        groupPages: pages,
      );
    }
    try {
      final result =
          state.isSearchMode
              ? await repository.search(
                userId: userId!,
                page: state.page,
                name: state.search,
                skillId: state.skillId,
                behaviorId: state.behaviorId,
              )
              : await repository.fetch(
                userId: userId!,
                groupPages: pages,
                search: state.search,
                skillId: state.skillId,
              );
      state = state.copyWith(
        result: DataState.onData(result),
        groupPages: pages,
        filterOptions:
            result.skills.isNotEmpty ? result.skills : state.filterOptions,
      );
      return null;
    } catch (error) {
      final message = error.toString();
      // On failure, leave the previously shown page/data untouched so the
      // pagination widget keeps highlighting the page that's actually shown.
      if (!hasData) {
        state = state.copyWith(result: DataState.onError(message));
      }
      return message;
    }
  }

  Future<String?> changeGroupPage(String groupId, int page) async {
    final updated = Map<String, int>.from(state.groupPages)..[groupId] = page;
    return fetch(groupPages: updated);
  }

  Future<void> applyFilters({
    required String search,
    String? skillId,
    String? behaviorId,
  }) async {
    final searchText = search.trim();
    state = state.copyWith(
      search: searchText,
      skillId: skillId,
      behaviorId: behaviorId,
      isSearchMode:
          searchText.isNotEmpty || skillId != null || behaviorId != null,
      page: 1,
      groupPages: const {},
      clearSkill: skillId == null,
      clearBehavior: behaviorId == null,
    );
    await fetch();
  }

  Future<void> reset() async {
    state = CourseCatalogState.initial();
    await fetch();
  }
}

int? _loggedInUserId(AuthState? auth) {
  return auth?.userProfile?.userId ?? auth?.user?.id;
}

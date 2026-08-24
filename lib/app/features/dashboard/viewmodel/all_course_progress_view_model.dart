import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/dashboard/repository/all_course_progress_repository.dart';

const _perPage = 100;

class AllCourseProgressState {
  const AllCourseProgressState({
    this.providerState = DataProviderState.idle,
    this.courses = const [],
    this.totalCourses = 0,
    this.page = 1,
    this.error,
  });

  final DataProviderState providerState;
  final List<AllCourseProgressItem> courses;
  final int totalCourses;
  final int page;
  final String? error;

  int get totalPages =>
      totalCourses == 0 ? 1 : ((totalCourses + _perPage - 1) ~/ _perPage);
  bool get hasNext => page < totalPages;
  bool get hasPrev => page > 1;

  AllCourseProgressState copyWith({
    DataProviderState? providerState,
    List<AllCourseProgressItem>? courses,
    int? totalCourses,
    int? page,
    String? error,
  }) => AllCourseProgressState(
    providerState: providerState ?? this.providerState,
    courses: courses ?? this.courses,
    totalCourses: totalCourses ?? this.totalCourses,
    page: page ?? this.page,
    error: error,
  );
}

class AllCourseProgressViewModel extends StateNotifier<AllCourseProgressState> {
  AllCourseProgressViewModel({required this.repository, required this.userId})
    : super(const AllCourseProgressState()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
    AllCourseProgressViewModel,
    AllCourseProgressState
  >((ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    return AllCourseProgressViewModel(
      repository: ref.watch(AllCourseProgressRepository.provider),
      userId: _loggedInUserId(auth),
    );
  });

  final AllCourseProgressRepository repository;
  final int? userId;

  Future<String?> fetch({int page = 1}) async {
    if (userId == null) {
      const message = 'The logged-in user ID is unavailable.';
      state = state.copyWith(
        providerState: DataProviderState.error,
        error: message,
      );
      return message;
    }
    final hasData = state.providerState == DataProviderState.data;
    if (!hasData) {
      state = state.copyWith(providerState: DataProviderState.loading, page: page);
    }
    try {
      final result = await repository.fetch(
        userId: userId!,
        page: page,
        perPage: _perPage,
      );
      if (!mounted) return null;
      state = state.copyWith(
        providerState: DataProviderState.data,
        courses: result.courses,
        totalCourses: result.totalCourses,
        page: page,
      );
      return null;
    } catch (error) {
      final message = error.toString();
      if (!hasData && mounted) {
        state = state.copyWith(
          providerState: DataProviderState.error,
          error: message,
        );
      }
      return message;
    }
  }

  Future<String?> goToPage(int page) {
    if (page >= 1 && page <= state.totalPages) return fetch(page: page);
    return Future.value(null);
  }
}

int? _loggedInUserId(AuthState? auth) =>
    auth?.userProfile?.userId ?? auth?.user?.id;

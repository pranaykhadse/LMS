import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/repository/enrolled_courses_repository.dart';

const _perPage = 10;

class EnrolledState {
  const EnrolledState({
    this.providerState = DataProviderState.idle,
    this.courses = const [],
    this.totalCourses = 0,
    this.page = 1,
    this.error,
  });

  final DataProviderState providerState;
  final List<DashboardCourse> courses;
  final int totalCourses;
  final int page;
  final String? error;

  int get totalPages =>
      totalCourses == 0 ? 1 : ((totalCourses + _perPage - 1) ~/ _perPage);
  bool get hasNext => page < totalPages;
  bool get hasPrev => page > 1;

  EnrolledState copyWith({
    DataProviderState? providerState,
    List<DashboardCourse>? courses,
    int? totalCourses,
    int? page,
    String? error,
  }) => EnrolledState(
    providerState: providerState ?? this.providerState,
    courses: courses ?? this.courses,
    totalCourses: totalCourses ?? this.totalCourses,
    page: page ?? this.page,
    error: error,
  );
}

class EnrolledCoursesViewModel extends StateNotifier<EnrolledState> {
  EnrolledCoursesViewModel({required this.repository, required this.userId})
    : super(const EnrolledState()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
    EnrolledCoursesViewModel,
    EnrolledState
  >((ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    return EnrolledCoursesViewModel(
      repository: ref.watch(EnrolledCoursesRepository.provider),
      userId: _loggedInUserId(auth),
    );
  });

  final EnrolledCoursesRepository repository;
  final int? userId;

  Future<void> fetch({int page = 1}) async {
    if (userId == null) {
      state = state.copyWith(
        providerState: DataProviderState.error,
        error: 'The logged-in user ID is unavailable.',
      );
      return;
    }
    state = state.copyWith(providerState: DataProviderState.loading, page: page);
    try {
      final result = await repository.fetch(
        userId: userId!,
        page: page,
        perPage: _perPage,
      );
      state = state.copyWith(
        providerState: DataProviderState.data,
        courses: result.courses,
        totalCourses: result.totalCourses,
        page: page,
      );
    } catch (error) {
      state = state.copyWith(
        providerState: DataProviderState.error,
        error: error.toString(),
      );
    }
  }

  void nextPage() { if (state.hasNext) fetch(page: state.page + 1); }
  void prevPage() { if (state.hasPrev) fetch(page: state.page - 1); }
  void goToPage(int page) {
    if (page >= 1 && page <= state.totalPages) fetch(page: page);
  }
}

int? _loggedInUserId(AuthState? auth) =>
    auth?.userProfile?.userId ?? auth?.user?.id;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/repository/enrolled_courses_repository.dart';

// Matches the 4-column desktop card grid (enrolled_courses_page.dart) so a
// page always fills whole rows instead of leaving 1-2 empty slots on the
// last row (10 / 4 columns left a dangling half row).
const _perPage = 8;

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

  int get perPage => _perPage;

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

  Future<String?> fetch({int page = 1}) async {
    if (userId == null) {
      const message = 'The logged-in user ID is unavailable.';
      state = state.copyWith(
        providerState: DataProviderState.error,
        error: message,
      );
      return message;
    }
    // Keep the currently shown page on screen while fetching another page
    // instead of flashing a full-screen spinner; only show the spinner when
    // there's nothing on screen yet (first load / after an error).
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
      // Leave the previously shown page/data in place on failure so the
      // pagination widget keeps highlighting the page that's actually shown.
      if (!hasData && mounted) {
        state = state.copyWith(
          providerState: DataProviderState.error,
          error: message,
        );
      }
      return message;
    }
  }

  Future<String?> nextPage() =>
      state.hasNext ? fetch(page: state.page + 1) : Future.value(null);
  Future<String?> prevPage() =>
      state.hasPrev ? fetch(page: state.page - 1) : Future.value(null);
  Future<String?> goToPage(int page) {
    if (page >= 1 && page <= state.totalPages) return fetch(page: page);
    return Future.value(null);
  }
}

int? _loggedInUserId(AuthState? auth) =>
    auth?.userProfile?.userId ?? auth?.user?.id;

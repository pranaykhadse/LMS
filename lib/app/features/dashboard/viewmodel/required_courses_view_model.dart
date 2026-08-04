import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/repository/required_courses_repository.dart';

const _limit = 10;

class RequiredCoursesState {
  const RequiredCoursesState({
    this.providerState = DataProviderState.idle,
    this.courses = const [],
    this.total = 0,
    this.totalPages = 1,
    this.page = 1,
    this.error,
  });

  final DataProviderState providerState;
  final List<DashboardCourse> courses;
  final int total;
  final int totalPages;
  final int page;
  final String? error;

  int get perPage => _limit;

  bool get hasNext => page < totalPages;
  bool get hasPrev => page > 1;

  RequiredCoursesState copyWith({
    DataProviderState? providerState,
    List<DashboardCourse>? courses,
    int? total,
    int? totalPages,
    int? page,
    String? error,
  }) => RequiredCoursesState(
    providerState: providerState ?? this.providerState,
    courses: courses ?? this.courses,
    total: total ?? this.total,
    totalPages: totalPages ?? this.totalPages,
    page: page ?? this.page,
    error: error,
  );
}

class RequiredCoursesViewModel extends StateNotifier<RequiredCoursesState> {
  RequiredCoursesViewModel({required this.repository, required this.userId})
    : super(const RequiredCoursesState()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
    RequiredCoursesViewModel,
    RequiredCoursesState
  >((ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    return RequiredCoursesViewModel(
      repository: ref.watch(RequiredCoursesRepository.provider),
      userId: _loggedInUserId(auth),
    );
  });

  final RequiredCoursesRepository repository;
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
        limit: _limit,
        type: 'required',
      );
      if (!mounted) return null;
      state = state.copyWith(
        providerState: DataProviderState.data,
        courses: result.courses,
        total: result.total,
        totalPages: result.pages > 0 ? result.pages : 1,
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

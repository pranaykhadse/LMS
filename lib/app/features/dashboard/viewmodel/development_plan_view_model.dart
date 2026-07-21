import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/repository/development_plan_repository.dart';

const _perPage = 10;

class DevelopmentPlanState {
  const DevelopmentPlanState({
    this.providerState = DataProviderState.idle,
    this.courses = const [],
    this.total = 0,
    this.page = 1,
    this.error,
  });

  final DataProviderState providerState;
  final List<DashboardCourse> courses;
  final int total;
  final int page;
  final String? error;

  int get totalPages => total == 0 ? 1 : ((total + _perPage - 1) ~/ _perPage);
  bool get hasNext => page < totalPages;
  bool get hasPrev => page > 1;

  DevelopmentPlanState copyWith({
    DataProviderState? providerState,
    List<DashboardCourse>? courses,
    int? total,
    int? page,
    String? error,
  }) => DevelopmentPlanState(
    providerState: providerState ?? this.providerState,
    courses: courses ?? this.courses,
    total: total ?? this.total,
    page: page ?? this.page,
    error: error,
  );
}

class DevelopmentPlanViewModel extends StateNotifier<DevelopmentPlanState> {
  DevelopmentPlanViewModel({required this.repository, required this.userId})
    : super(const DevelopmentPlanState()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
    DevelopmentPlanViewModel,
    DevelopmentPlanState
  >((ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    return DevelopmentPlanViewModel(
      repository: ref.watch(DevelopmentPlanRepository.provider),
      userId: _loggedInUserId(auth),
    );
  });

  final DevelopmentPlanRepository repository;
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
        total: result.total,
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

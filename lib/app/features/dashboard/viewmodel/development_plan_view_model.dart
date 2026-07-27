import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/repository/development_plan_repository.dart'
    show DevelopmentPlanRepository, NonCoursePlanResult;

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
      state = state.copyWith(
        providerState: DataProviderState.data,
        courses: result.courses,
        total: result.total,
        page: page,
      );
      return null;
    } catch (error) {
      final message = error.toString();
      if (!hasData) {
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

  Future<NonCoursePlanResult> addCustomPlanItem(String name) async {
    final result = await repository.addCustomPlanItem(name: name);
    if (result.success) {
      await fetch(page: 1);
    }
    return result;
  }
}

int? _loggedInUserId(AuthState? auth) =>
    auth?.userProfile?.userId ?? auth?.user?.id;

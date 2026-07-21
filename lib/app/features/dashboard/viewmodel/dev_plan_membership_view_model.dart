import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/paginated_fetch.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/repository/development_plan_repository.dart';

/// The course-catalog and my-courses APIs don't return per-course
/// development-plan membership, so every "+/-" button built off them was
/// defaulting to "not in plan" — even right after the course was added.
/// This fetches the user's real development-plan course-id set from
/// lms-screen/development-plan (looping every page) and keeps it updated
/// locally as courses are added/removed, so every card across the app
/// reflects actual membership instead of guessing.
class DevPlanMembershipViewModel extends StateNotifier<Set<int>> {
  DevPlanMembershipViewModel({required this.repository, required this.userId})
      : super(const {}) {
    if (userId != null) fetch();
  }

  static final provider =
      StateNotifierProvider.autoDispose<DevPlanMembershipViewModel, Set<int>>(
    (ref) {
      final auth = ref.watch(AuthStateNotifier.provider);
      return DevPlanMembershipViewModel(
        repository: ref.watch(DevelopmentPlanRepository.provider),
        userId: _loggedInUserId(auth),
      );
    },
  );

  final DevelopmentPlanRepository repository;
  final int? userId;

  Future<void> fetch() async {
    if (userId == null) return;
    final courses = await fetchAllPages<DashboardCourse>(
      fetchPage: (page, perPage) async {
        final result = await repository.fetch(
          userId: userId!,
          page: page,
          perPage: perPage,
        );
        return result.courses;
      },
    );
    if (mounted) state = courses.map((c) => c.id).toSet();
  }

  void markInPlan(int courseId) {
    if (mounted) state = {...state, courseId};
  }

  void markRemoved(int courseId) {
    if (mounted) state = {...state}..remove(courseId);
  }
}

int? _loggedInUserId(AuthState? auth) =>
    auth?.userProfile?.userId ?? auth?.user?.id;

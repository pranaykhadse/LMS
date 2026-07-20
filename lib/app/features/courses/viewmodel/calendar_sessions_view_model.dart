import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/model/course_catalog.dart';
import 'package:lms/app/features/courses/repository/course_catalog_repository.dart';

/// Loads the entire course catalog (all groups, unpaginated) in one call so
/// the Calendar can show every course session, not just the current
/// catalog page or the user's own enrolled courses.
class CalendarSessionsViewModel
    extends StateNotifier<DataState<List<CatalogCourse>>> {
  CalendarSessionsViewModel({required this.repository, required this.userId})
      : super(DataState.idle<List<CatalogCourse>>()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
      CalendarSessionsViewModel, DataState<List<CatalogCourse>>>((ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    return CalendarSessionsViewModel(
      repository: ref.watch(CourseCatalogRepository.provider),
      userId: auth?.userProfile?.userId ?? auth?.user?.id,
    );
  });

  final CourseCatalogRepository repository;
  final int? userId;

  Future<void> fetch() async {
    if (userId == null) {
      state = DataState.onError('User not logged in.');
      return;
    }
    state = DataState.loading<List<CatalogCourse>>();
    try {
      final result = await repository.fetch(userId: userId!, perPage: 500);
      state = DataState.onData(result.courses);
    } catch (e) {
      state = DataState.onError(_friendly(e));
    }
  }

  String _friendly(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Session expired. Please log in again.';
    }
    if (msg.contains('SocketException') || msg.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    return 'Unable to load sessions. Please try again.';
  }
}

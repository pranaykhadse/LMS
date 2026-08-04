import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/courses/model/calendar_event.dart';
import 'package:lms/app/features/courses/repository/calendar_view_repository.dart';

class CalendarViewModel extends StateNotifier<DataState<CalendarViewResult>> {
  CalendarViewModel({required this.repository, required this.userId})
      : super(DataState.idle<CalendarViewResult>()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
      CalendarViewModel, DataState<CalendarViewResult>>((ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    return CalendarViewModel(
      repository: ref.watch(CalendarViewRepository.provider),
      userId: _loggedInUserId(auth),
    );
  });

  final CalendarViewRepository repository;
  final int? userId;

  Future<void> fetch() async {
    if (userId == null) {
      state = DataState.onError('The logged-in user ID is unavailable.');
      return;
    }
    state = DataState.loading<CalendarViewResult>();
    try {
      final data = await repository.fetch(userId: userId!);
      if (!mounted) return;
      state = DataState.onData(data);
    } catch (e) {
      if (!mounted) return;
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
    return 'Unable to load calendar events. Please try again.';
  }
}

int? _loggedInUserId(AuthState? auth) =>
    auth?.userProfile?.userId ?? auth?.user?.id;

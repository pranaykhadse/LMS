import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/dashboard/model/my_course_item.dart';
import 'package:lms/app/features/dashboard/repository/my_courses_repository.dart';

class MyCoursesViewModel extends StateNotifier<DataState<MyCoursesResult>> {
  MyCoursesViewModel({required this.repository})
      : super(DataState.idle<MyCoursesResult>()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
      MyCoursesViewModel, DataState<MyCoursesResult>>((ref) {
    return MyCoursesViewModel(
      repository: ref.watch(MyCoursesRepository.provider),
    );
  });

  final MyCoursesRepository repository;

  Future<void> fetch() async {
    state = DataState.loading<MyCoursesResult>();
    try {
      final data = await repository.fetch();
      state = DataState.onData(data);
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
    return 'Unable to load your courses. Please try again.';
  }
}

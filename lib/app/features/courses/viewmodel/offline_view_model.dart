import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/repository/offline_course_repository.dart';
import 'package:lms/app/features/courses/viewmodel/file_cache_view_model.dart';

class OfflineViewModel extends ChangeNotifier {
  static final provider = ChangeNotifierProvider<OfflineViewModel>((ref) {
    return OfflineViewModel(
      ref: ref,
      repository: ref.watch(OfflineCourseRepository.provider),
    );
  });

  final OfflineCourseRepository repository;
  final Ref ref;

  OfflineViewModel({required this.repository, required this.ref}) {
    _fetch();
  }
  DataState<List<Course>> courses = DataState.idle();
  Future<void> download(Course course) async {
    _downloading.add(course);
    notifyListeners();

    try {
      final classes = await repository.download(course);
      final futures = <Future>[];
      for (var classInfo in classes) {
        if (classInfo.classInfo?.videoUploadUrl != null) {
          futures.add(
            ref
                .read(FileCacheViewModel.provider)
                .downloadFile(classInfo.classInfo!.videoUploadUrl!),
          );
        }
        if (classInfo.classInfo?.articleFile != null) {
          futures.add(
            ref
                .read(FileCacheViewModel.provider)
                .downloadFile(classInfo.classInfo!.articleFile!),
          );
        }
      }
      await Future.wait(futures);
    } finally {
      _downloading.remove(course);
      notifyListeners();
    }
    _fetch();
  }

  Future<void> _fetch() async {
    courses = DataState.loading();
    try {
      courses = DataState.onData(await repository.getCachedCourses());
    } catch (e) {
      courses = DataState.onError(e.toString());
    }
    notifyListeners();
  }

  bool isAvailable(Course course) {
    return courses.data?.any((e) => e.id == course.id) ?? false;
  }

  final List<Course> _downloading = [];
  bool isDownloading(Course course) {
    return _downloading.any((e) => e.id == course.id);
  }
}

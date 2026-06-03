import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/repository/offline_course_repository.dart';
import 'package:lms/app/features/courses/viewmodel/file_cache_view_model.dart';

// ── Internal progress model ───────────────────────────────────────────────────

class _CourseDownloadProgress {
  int completed;
  final int total;
  _CourseDownloadProgress({required this.completed, required this.total});
  double get fraction => total == 0 ? 0.0 : completed / total;
}

// ─────────────────────────────────────────────────────────────────────────────

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

  // ── Per-course download progress ──────────────────────────────────────────

  final Map<int, _CourseDownloadProgress> _progress = {};

  /// Returns a 0.0–1.0 progress value while a course is downloading,
  /// or `null` if the course is not currently being downloaded.
  double? downloadProgress(Course course) {
    final p = _progress[course.id];
    return p?.fraction;
  }

  // ── Download ──────────────────────────────────────────────────────────────

  Future<void> download(Course course) async {
    _downloading.add(course);
    notifyListeners();

    try {
      final classes = await repository.download(course);

      // ── Count total files (videos + articles + participant guide) ──────────
      int total = 0;
      for (final c in classes) {
        if (_validUrl(c.classInfo?.videoUploadUrl)) total++;
        if (_validUrl(c.classInfo?.articleFile)) total++;
      }
      final pgUrl = course.participantGuideFile?.toString();
      final wmUrl = course.wrapMethodologyFile?.toString();
      if (_validUrl(pgUrl)) total++;
      if (_validUrl(wmUrl)) total++;

      _progress[course.id ?? -1] = _CourseDownloadProgress(
        completed: 0,
        total: total,
      );
      notifyListeners();

      // ── Queue all downloads, incrementing completed counter per file ───────
      final fileVM = ref.read(FileCacheViewModel.provider);
      final futures = <Future>[];

      void addDownload(String url) {
        futures.add(
          fileVM.downloadFile(url).then((_) {
            _progress[course.id ?? -1]?.completed++;
            notifyListeners();
          }),
        );
      }

      for (final c in classes) {
        if (_validUrl(c.classInfo?.videoUploadUrl)) {
          addDownload(c.classInfo!.videoUploadUrl!);
        }
        if (_validUrl(c.classInfo?.articleFile)) {
          addDownload(c.classInfo!.articleFile!);
        }
      }
      // Participant guide + Wrap Methodology (course-level PDFs)
      if (_validUrl(pgUrl)) addDownload(pgUrl!);
      if (_validUrl(wmUrl)) addDownload(wmUrl!);

      await Future.wait(futures);
    } finally {
      _downloading.remove(course);
      // Use the same null-safe key that was used when the entry was created.
      _progress.remove(course.id ?? -1);
      notifyListeners();
    }
    _fetch();
  }

  // ── Remove offline ────────────────────────────────────────────────────────

  /// Removes [course] from the offline index so the card switches back to
  /// "Save Offline". Downloaded files (videos, PDFs) are intentionally kept
  /// on device so they don't need to be re-downloaded if saved offline again.
  Future<void> removeOffline(Course course) async {
    await repository.removeCourse(course);
    await _fetch();
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  Future<void> _fetch() async {
    courses = DataState.loading();
    try {
      courses = DataState.onData(await repository.getCachedCourses());
    } catch (e) {
      courses = DataState.onError(e.toString());
    }
    notifyListeners();
  }

  static bool _validUrl(String? url) =>
      url != null && url.trim().isNotEmpty;

  // ── Public helpers ────────────────────────────────────────────────────────

  bool isAvailable(Course course) {
    return courses.data?.any((e) => e.id == course.id) ?? false;
  }

  /// Returns the locally-cached lesson list for [courseId].
  Future<List<CourseClass>> getCachedClasses(String courseId) {
    return repository.getCachedClasses(courseId);
  }

  final List<Course> _downloading = [];
  bool isDownloading(Course course) {
    return _downloading.any((e) => e.id == course.id);
  }
}

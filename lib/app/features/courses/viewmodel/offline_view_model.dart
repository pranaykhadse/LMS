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

  /// courseId → Unix-ms timestamp of when that course was last made offline.
  Map<int, int> offlineTimestamps = {};

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
      _progress[course.id ?? -1] = _CourseDownloadProgress(
        completed: 0,
        total: 1,
      );
      notifyListeners();

      // Save the course + lesson metadata first.
      final classes = await repository.download(course);

      // Then download every lesson's actual content (video/PDF/article/
      // agreement/recording) too - a "saved offline" course must actually
      // be usable offline, not just show up in the offline list with
      // nothing playable inside it.
      final urls = <String>{};
      for (final c in classes) {
        if (_validUrl(c.classInfo?.videoUploadUrl)) urls.add(c.classInfo!.videoUploadUrl!);
        if (_validUrl(c.classInfo?.articleFile)) urls.add(c.classInfo!.articleFile!);
        if (_validUrl(c.scannedPdf)) urls.add(c.scannedPdf!);
        urls.addAll(c.recordingUrls.where(_validUrl));
      }
      final pgUrl = course.participantGuideFile?.toString();
      final wmUrl = course.wrapMethodologyFile?.toString();
      if (_validUrl(pgUrl)) urls.add(pgUrl!);
      if (_validUrl(wmUrl)) urls.add(wmUrl!);

      _progress[course.id ?? -1] = _CourseDownloadProgress(
        completed: 0,
        total: urls.isEmpty ? 1 : urls.length,
      );
      notifyListeners();

      final fileVM = ref.read(FileCacheViewModel.provider);
      var completed = 0;
      for (final url in urls) {
        await fileVM.downloadFile(url);
        completed++;
        _progress[course.id ?? -1]?.completed = completed;
        notifyListeners();
      }
      if (urls.isEmpty) _progress[course.id ?? -1]?.completed = 1;
    } finally {
      _downloading.remove(course);
      // Use the same null-safe key that was used when the entry was created.
      _progress.remove(course.id ?? -1);
      notifyListeners();
    }
    _fetch();
  }

  // ── Remove offline ────────────────────────────────────────────────────────

  /// Removes [course] from the offline index and deletes all downloaded files.
  Future<void> removeOffline(Course course) async {
    final fileVM = ref.read(FileCacheViewModel.provider);

    // Delete all per-lesson cached files.
    final classes = await repository.getCachedClasses(
      course.id?.toString() ?? "",
    );
    for (final c in classes) {
      if (_validUrl(c.classInfo?.videoUploadUrl)) {
        fileVM.delete(c.classInfo!.videoUploadUrl!);
      }
      if (_validUrl(c.classInfo?.articleFile)) {
        fileVM.delete(c.classInfo!.articleFile!);
      }
      if (_validUrl(c.scannedPdf)) {
        fileVM.delete(c.scannedPdf!);
      }
      for (final url in c.recordingUrls) {
        fileVM.delete(url);
      }
    }

    // Delete course-level PDFs.
    final pgUrl = course.participantGuideFile?.toString();
    final wmUrl = course.wrapMethodologyFile?.toString();
    if (_validUrl(pgUrl)) {
      fileVM.delete(pgUrl!);
    }
    if (_validUrl(wmUrl)) {
      fileVM.delete(wmUrl!);
    }

    await repository.removeCourse(course);
    await _fetch();
  }

  /// Same as [removeOffline], but by courseId - for callers (e.g. cancelling
  /// a course's registration) that don't have a full [Course] object on
  /// hand. No-op if the course was never downloaded offline.
  Future<void> removeOfflineByCourseId(int courseId) async {
    final cached = await repository.getCachedCourse(courseId.toString());
    if (cached == null) return;
    await removeOffline(cached);
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  Future<void> _fetch() async {
    courses = DataState.loading();
    try {
      courses = DataState.onData(await repository.getCachedCourses());
      final tsMap = await repository.getOfflineTimestamps();
      offlineTimestamps = tsMap.map(
        (k, v) => MapEntry(int.tryParse(k) ?? 0, v),
      );
    } catch (e) {
      courses = DataState.onError(e.toString());
    }
    notifyListeners();
  }

  static bool _validUrl(String? url) => url != null && url.trim().isNotEmpty;

  // ── Public helpers ────────────────────────────────────────────────────────

  bool isAvailable(Course course) {
    return courses.data?.any((e) => e.id == course.id) ?? false;
  }

  /// Same as [isAvailable], but by raw courseId - for the many course-listing
  /// screens (dashboard, catalog, my courses, calendar) whose own card model
  /// isn't the courses/model/course.dart Course type.
  bool isAvailableById(int? courseId) {
    return courseId != null &&
        (courses.data?.any((e) => e.id == courseId) ?? false);
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

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/repository/course_join_detail_repository.dart';
import 'package:lms/app/features/courses/repository/offline_course_repository.dart';
import 'package:lms/app/features/courses/viewmodel/file_cache_view_model.dart';
import 'package:lms/app/features/dashboard/model/notification_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/notifications_view_model.dart';

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
      // agreement/peer-coaching/recording) too - a "saved offline" course
      // must actually be usable offline, not just show up in the offline
      // list with nothing playable inside it.
      final urls = <String>{};
      for (final c in classes) {
        if (_validUrl(c.classInfo?.videoUploadUrl)) urls.add(c.classInfo!.videoUploadUrl!);
        if (_validUrl(c.classInfo?.articleFile)) urls.add(c.classInfo!.articleFile!);
        if (_validUrl(c.classInfo?.peerCoachingFile)) urls.add(c.classInfo!.peerCoachingFile!);
        if (_validUrl(c.scannedPdf)) urls.add(c.scannedPdf!);
        urls.addAll(c.recordingUrls.where(_validUrl));
      }
      final pgUrl = course.participantGuideFile?.toString();
      final wmUrl = course.wrapMethodologyFile?.toString();
      if (_validUrl(pgUrl)) urls.add(pgUrl!);
      if (_validUrl(wmUrl)) urls.add(wmUrl!);

      // Certificates are raw HTML content, not a downloadable file URL -
      // allcourse/events (used for everything above) doesn't carry them at
      // all, only a certificate id reference. Fetched separately from
      // join-course-detail, the same source the live course detail page
      // uses for these.
      final certificates = await _certificateContents(course.id);

      _progress[course.id ?? -1] = _CourseDownloadProgress(
        completed: 0,
        total: urls.isEmpty && certificates.isEmpty
            ? 1
            : urls.length + certificates.length,
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
      for (final entry in certificates.entries) {
        await fileVM.saveContent(entry.key, utf8.encode(entry.value));
        completed++;
        _progress[course.id ?? -1]?.completed = completed;
        notifyListeners();
      }
      if (urls.isEmpty && certificates.isEmpty) {
        _progress[course.id ?? -1]?.completed = 1;
      }
    } catch (e) {
      _notifyDownload(
        title: 'Download Failed',
        message:
            "Couldn't save '${course.name ?? 'this course'}' for offline access.",
        idSuffix: 'failed-${course.id}-${DateTime.now().millisecondsSinceEpoch}',
      );
      rethrow;
    } finally {
      _downloading.remove(course);
      // Use the same null-safe key that was used when the entry was created.
      _progress.remove(course.id ?? -1);
      notifyListeners();
    }
    _notifyDownload(
      title: 'Download Complete',
      message: "'${course.name ?? 'Course'}' is now available offline.",
      idSuffix: 'complete-${course.id}-${DateTime.now().millisecondsSinceEpoch}',
    );
    _fetch();
  }

  /// Surfaces a download's outcome as a local (client-generated) entry in
  /// the Notifications screen - there's no backend endpoint for this, so it
  /// only lives in NotificationsViewModel's in-memory state (see addLocal).
  void _notifyDownload({
    required String title,
    required String message,
    required String idSuffix,
  }) {
    ref.read(NotificationsViewModel.provider.notifier).addLocal(
          NotificationItem(
            id: 'download-$idSuffix',
            title: title,
            message: message,
            type: 'download',
            isRead: false,
            createdAt: DateTime.now(),
          ),
        );
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
      if (_validUrl(c.classInfo?.peerCoachingFile)) {
        fileVM.delete(c.classInfo!.peerCoachingFile!);
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

    // Delete any cached certificates too - same lookup as download().
    // Best-effort: if this fails (e.g. genuinely offline with nothing
    // cached for join-course-detail either), any downloaded certificate
    // cache entries are simply left orphaned rather than actively cleaned
    // up - not worth blocking removal of everything else over.
    final certificates = await _certificateContents(course.id);
    for (final key in certificates.keys) {
      fileVM.delete(key);
    }

    await repository.removeCourse(course);
    await _fetch();
  }

  /// classId → certificate HTML for every class in [courseId] that carries
  /// one - see the comment in [download] for why this needs its own fetch.
  /// Returns an empty map (not an error) on any failure; a missing
  /// certificate shouldn't block the rest of the course from downloading
  /// or being removed.
  Future<Map<String, String>> _certificateContents(int? courseId) async {
    if (courseId == null) return {};
    final userId = ref.read(AuthStateNotifier.provider)?.user?.id;
    if (userId == null) return {};
    try {
      final detail = await ref
          .read(CourseJoinDetailRepository.provider)
          .fetch(userId: userId, courseId: courseId);
      final result = <String, String>{};
      for (final item in detail.structures) {
        final html = item.certificateHtml;
        final classId = item.classId;
        if (html == null || html.isEmpty || classId == null) continue;
        result['certificate_class_$classId'] = html;
      }
      return result;
    } catch (_) {
      return {};
    }
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

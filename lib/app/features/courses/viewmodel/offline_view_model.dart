import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/model/course_join_detail.dart';
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

      // Save the course + lesson metadata first (legacy allcourse/events +
      // roster pipeline - kept for the offline course list/metadata index
      // this populates, see repository.getCachedClasses/getCachedCourses).
      final classes = await repository.download(course);

      // The actual course page (course_classes_page.dart) is built
      // entirely on join-course-detail, not on allcourse/events - and
      // that's the one place every downloadable URL (video/PDF/agreement/
      // peer-coaching/recording/participant guide) is reliably present.
      // allcourse/events + the roster enrichment above routinely came back
      // with recording URLs missing, and course-level attachments like the
      // participant guide aren't even in the lightweight listing endpoints
      // most "Save Offline" taps originate from (catalog/dashboard cards
      // only carry a summary, not the full detail) - `course.
      // participantGuideFile` was frequently just null there. Fetching
      // this once here also happens to warm join-course-detail's own
      // offline cache (see CourseJoinDetailRepository.fetch), which is
      // what actually lets the course page open with no connection at all.
      final detail = await _fetchJoinDetail(course.id);

      // Then download every lesson's actual content (video/PDF/article/
      // agreement/peer-coaching/recording) too - a "saved offline" course
      // must actually be usable offline, not just show up in the offline
      // list with nothing playable inside it.
      final urls = <String>{};
      for (final item in detail?.structures ?? const []) {
        if (_validUrl(item.downloadUrl)) urls.add(item.downloadUrl!);
        urls.addAll(item.recordingUrls.where(_validUrl));
      }
      // Fallback to the legacy allcourse/events-sourced fields too, in
      // case join-course-detail's fetch failed above (e.g. saving offline
      // while already offline, with nothing cached for it yet either) -
      // better to grab whatever those had than nothing.
      for (final c in classes) {
        if (_validUrl(c.classInfo?.videoUploadUrl)) urls.add(c.classInfo!.videoUploadUrl!);
        if (_validUrl(c.classInfo?.articleFile)) urls.add(c.classInfo!.articleFile!);
        if (_validUrl(c.classInfo?.peerCoachingFile)) urls.add(c.classInfo!.peerCoachingFile!);
        if (_validUrl(c.scannedPdf)) urls.add(c.scannedPdf!);
        urls.addAll(c.recordingUrls.where(_validUrl));
      }
      final pgUrl = detail?.participantGuide ?? course.participantGuideFile?.toString();
      final wmUrl = course.wrapMethodologyFile?.toString();
      if (_validUrl(pgUrl)) urls.add(pgUrl!);
      if (_validUrl(wmUrl)) urls.add(wmUrl!);

      // Certificates are raw HTML content, not a downloadable file URL -
      // pulled from the same join-course-detail fetch above.
      final certificates = _certificateContents(detail);

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

    // Same join-course-detail source download() saves from - deletes need
    // to look in the same place content actually got saved, not just the
    // legacy allcourse/events fields (which is all this used to check).
    final detail = await _fetchJoinDetail(course.id);
    for (final item in detail?.structures ?? const []) {
      if (_validUrl(item.downloadUrl)) fileVM.delete(item.downloadUrl!);
      for (final url in item.recordingUrls) {
        fileVM.delete(url);
      }
    }

    // Delete all per-lesson cached files from the legacy pipeline too -
    // harmless no-op for anything not actually cached under these keys,
    // and catches whatever download() fell back to saving from allcourse/
    // events when join-course-detail's fetch failed for it.
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
    final pgUrl = detail?.participantGuide ?? course.participantGuideFile?.toString();
    final wmUrl = course.wrapMethodologyFile?.toString();
    if (_validUrl(pgUrl)) {
      fileVM.delete(pgUrl!);
    }
    if (_validUrl(wmUrl)) {
      fileVM.delete(wmUrl!);
    }

    // Delete any cached certificates too - same lookup as download().
    for (final key in _certificateContents(detail).keys) {
      fileVM.delete(key);
    }

    await repository.removeCourse(course);
    await _fetch();
  }

  /// Fetches the course's full join-course-detail - the same authoritative
  /// source the live course page renders from (and the one place every
  /// downloadable URL, participant guide, and certificate reliably lives -
  /// see the comment in [download]). Returns null on any failure (e.g.
  /// genuinely offline right now with nothing cached for this course yet)
  /// rather than throwing - callers fall back to whatever the legacy
  /// allcourse/events pipeline already has.
  Future<CourseJoinDetail?> _fetchJoinDetail(int? courseId) async {
    if (courseId == null) return null;
    final userId = ref.read(AuthStateNotifier.provider)?.user?.id;
    if (userId == null) return null;
    try {
      return await ref
          .read(CourseJoinDetailRepository.provider)
          .fetch(userId: userId, courseId: courseId);
    } catch (_) {
      return null;
    }
  }

  /// classId → certificate HTML for every class in [detail] that carries
  /// one - see the comment in [download] for why certificates need this
  /// separate source instead of allcourse/events.
  Map<String, String> _certificateContents(CourseJoinDetail? detail) {
    final result = <String, String>{};
    for (final item in detail?.structures ?? const []) {
      final html = item.certificateHtml;
      final classId = item.classId;
      if (html == null || html.isEmpty || classId == null) continue;
      result['certificate_class_$classId'] = html;
    }
    return result;
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

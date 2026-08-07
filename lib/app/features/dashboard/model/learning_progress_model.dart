class LearningProgressData {
  const LearningProgressData({
    required this.summary,
    required this.continueLearning,
    required this.upcomingSessions,
    required this.progressStatus,
    required this.requiredForYou,
    required this.extras,
  });

  final LearningProgressSummary summary;
  final ContinueLearningInfo? continueLearning;
  final List<UpcomingSession> upcomingSessions;
  final List<CourseProgressItem> progressStatus;
  final List<RequiredCourseItem> requiredForYou;

  /// The richer "dashboard" block this same endpoint also returns -
  /// continue-learning entries with descriptions/logos, discussion board
  /// activity, and rewards - none of which the old lms-screen/dashboard
  /// endpoint provided.
  final DashboardExtras extras;

  factory LearningProgressData.fromJson(Map<String, dynamic> json) {
    final payload =
        json['payload'] is Map
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : json;

    final rawSummary = payload['summary'] is Map ? payload['summary'] as Map : const {};
    final rawContinue = payload['continue_learning'] is Map ? payload['continue_learning'] as Map : null;

    final rawUpcoming = (payload['upcoming_sessions'] as List? ?? const []);
    final rawProgress = (payload['progress_status'] as List? ?? const []);
    final rawRequired =
        (payload['required_for_you'] as List? ??
        payload['required_courses'] as List? ??
        const []);
    final rawDashboard = payload['dashboard'] is Map ? payload['dashboard'] as Map : const {};

    return LearningProgressData(
      summary: LearningProgressSummary.fromJson(Map<String, dynamic>.from(rawSummary)),
      continueLearning:
          rawContinue != null
              ? ContinueLearningInfo.fromJson(Map<String, dynamic>.from(rawContinue))
              : null,
      upcomingSessions:
          rawUpcoming
              .whereType<Map>()
              .map((e) => UpcomingSession.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
      progressStatus:
          rawProgress
              .whereType<Map>()
              .map((e) => CourseProgressItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
      requiredForYou:
          rawRequired
              .whereType<Map>()
              .map((e) => RequiredCourseItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
      extras: DashboardExtras.fromJson(Map<String, dynamic>.from(rawDashboard)),
    );
  }
}

class LearningProgressSummary {
  const LearningProgressSummary({
    required this.enrolledCourses,
    required this.completedCourses,
    required this.requiredCourses,
    required this.overallProgress,
  });

  final int enrolledCourses;
  final int completedCourses;
  final int requiredCourses;
  final int overallProgress;

  factory LearningProgressSummary.fromJson(Map<String, dynamic> json) =>
      LearningProgressSummary(
        enrolledCourses: _asInt(json['enrolled_courses'] ?? json['enrolled']),
        completedCourses: _asInt(json['completed_courses'] ?? json['completed']),
        requiredCourses: _asInt(json['required_courses'] ?? json['required']),
        overallProgress: _asInt(json['overall_progress'] ?? json['overall']),
      );
}

class ContinueLearningInfo {
  const ContinueLearningInfo({
    required this.courseId,
    required this.classId,
    required this.courseName,
  });

  final String courseId;
  final String classId;
  final String courseName;

  factory ContinueLearningInfo.fromJson(Map<String, dynamic> json) =>
      ContinueLearningInfo(
        courseId: json['course_id']?.toString() ?? '',
        classId: json['class_id']?.toString() ?? '',
        courseName: json['course_name']?.toString() ?? '',
      );
}

class UpcomingSession {
  const UpcomingSession({
    required this.courseId,
    required this.classId,
    required this.courseName,
    required this.startDate,
    required this.startTime,
    this.endTime,
    this.instructor,
  });

  final String courseId;
  final String classId;
  final String courseName;
  final String? startDate;
  final String? startTime;
  final String? endTime;
  final String? instructor;

  /// The API sends dates/times in UTC with no timezone marker, same as
  /// the Calendar endpoint - parsed as UTC and converted to local time so
  /// the displayed time matches what the learner actually sees the
  /// session start.
  DateTime? get startDateTime {
    final date = startDate;
    if (date == null) return null;
    return _combineDateAndTime(date, startTime);
  }

  factory UpcomingSession.fromJson(Map<String, dynamic> json) =>
      UpcomingSession(
        courseId: json['course_id']?.toString() ?? '',
        classId: json['class_id']?.toString() ?? '',
        courseName: json['course_name']?.toString() ?? '',
        startDate: json['start_date']?.toString(),
        startTime: json['start_time']?.toString(),
        endTime: json['end_time']?.toString(),
        instructor: _nullableString(json['instructor']),
      );
}

class CourseProgressItem {
  const CourseProgressItem({
    required this.courseId,
    required this.courseName,
    required this.progress,
  });

  final String courseId;
  final String courseName;
  final int progress;

  factory CourseProgressItem.fromJson(Map<String, dynamic> json) =>
      CourseProgressItem(
        courseId: json['course_id']?.toString() ?? '',
        courseName: json['course_name']?.toString() ?? '',
        progress: _asInt(json['progress']),
      );
}

class RequiredCourseItem {
  const RequiredCourseItem({
    required this.courseId,
    required this.courseName,
    this.progressLabel,
  });

  final String courseId;
  final String courseName;

  /// Raw label straight from the API - e.g. "0%" or "Not Enrolled" - shown
  /// as-is rather than parsed into a number, since "Not Enrolled" isn't a
  /// percentage.
  final String? progressLabel;

  factory RequiredCourseItem.fromJson(Map<String, dynamic> json) =>
      RequiredCourseItem(
        courseId: json['course_id']?.toString() ?? '',
        courseName: json['course_name']?.toString() ?? json['name']?.toString() ?? '',
        progressLabel: _nullableString(json['progress']),
      );
}

// ─── Dashboard-only extras ──────────────────────────────────────────────────

class DashboardExtras {
  const DashboardExtras({
    required this.continueLearning,
    required this.discussionBoards,
    required this.rewards,
  });

  final List<DashboardContinueLearningItem> continueLearning;
  final List<DashboardDiscussionBoardItem> discussionBoards;
  final DashboardRewards? rewards;

  factory DashboardExtras.fromJson(Map<String, dynamic> json) => DashboardExtras(
        continueLearning: (json['continue_learning'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => DashboardContinueLearningItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        discussionBoards: (json['discussion_boards'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => DashboardDiscussionBoardItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        rewards: json['rewards'] is Map
            ? DashboardRewards.fromJson(Map<String, dynamic>.from(json['rewards'] as Map))
            : null,
      );
}

class DashboardContinueLearningItem {
  const DashboardContinueLearningItem({
    required this.courseId,
    required this.courseName,
    required this.description,
    required this.logoLink,
    required this.classId,
    required this.className,
  });

  final String courseId;
  final String courseName;
  final String description;
  final String? logoLink;
  final String classId;
  final String className;

  factory DashboardContinueLearningItem.fromJson(Map<String, dynamic> json) =>
      DashboardContinueLearningItem(
        courseId: json['course_id']?.toString() ?? '',
        courseName: json['course_name']?.toString() ?? '',
        description: _stripHtml(json['description']?.toString() ?? ''),
        logoLink: _nullableString(json['logo_link']),
        classId: json['class_id']?.toString() ?? '',
        className: json['class_name']?.toString() ?? '',
      );
}

class DashboardDiscussionBoardItem {
  const DashboardDiscussionBoardItem({
    required this.learningEventId,
    required this.courseId,
    required this.title,
    required this.replyCount,
    required this.lastRepliedBy,
    required this.lastReply,
  });

  final String learningEventId;
  final String courseId;
  final String title;
  final int replyCount;
  final String lastRepliedBy;

  /// Already a friendly relative string from the API (e.g. "8 hours ago"),
  /// not a raw timestamp - shown as-is.
  final String lastReply;

  factory DashboardDiscussionBoardItem.fromJson(Map<String, dynamic> json) =>
      DashboardDiscussionBoardItem(
        learningEventId: json['learning_event_id']?.toString() ?? '',
        courseId: json['course_id']?.toString() ?? '',
        title: json['learning_event_name']?.toString() ?? '',
        replyCount: _asInt(json['reply_count']),
        lastRepliedBy: json['last_replied_by']?.toString() ?? '',
        lastReply: json['last_reply']?.toString() ?? '',
      );
}

class DashboardRewardActivity {
  const DashboardRewardActivity({required this.label, required this.points});
  final String label;
  final int points;

  factory DashboardRewardActivity.fromJson(Map<String, dynamic> json) =>
      DashboardRewardActivity(
        label: json['label']?.toString() ?? '',
        points: _asInt(json['points']),
      );
}

class DashboardRewards {
  const DashboardRewards({required this.totalPoints, required this.activity});
  final int totalPoints;
  final List<DashboardRewardActivity> activity;

  factory DashboardRewards.fromJson(Map<String, dynamic> json) => DashboardRewards(
        totalPoints: _asInt(json['total_points']),
        activity: (json['activity'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => DashboardRewardActivity.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

// ─── Shared parsing helpers ─────────────────────────────────────────────────

DateTime? _combineDateAndTime(String dateStr, String? timeStr) {
  final date = DateTime.tryParse(dateStr);
  if (date == null) return null;
  if (timeStr == null || timeStr.isEmpty) {
    return DateTime.utc(date.year, date.month, date.day).toLocal();
  }
  final parts = timeStr.split(':');
  final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
  return DateTime.utc(date.year, date.month, date.day, hour, minute, second).toLocal();
}

String _stripHtml(String value) {
  final withoutTags = value.replaceAll(RegExp(r'<[^>]*>'), ' ');
  return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

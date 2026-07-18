class LearningProgressData {
  const LearningProgressData({
    required this.summary,
    required this.continueLearning,
    required this.upcomingSessions,
    required this.progressStatus,
    required this.requiredForYou,
  });

  final LearningProgressSummary summary;
  final ContinueLearningInfo? continueLearning;
  final List<UpcomingSession> upcomingSessions;
  final List<CourseProgressItem> progressStatus;
  final List<RequiredCourseItem> requiredForYou;

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
    required this.courseName,
    required this.startDate,
    required this.startTime,
  });

  final String courseName;
  final String? startDate;
  final String? startTime;

  factory UpcomingSession.fromJson(Map<String, dynamic> json) =>
      UpcomingSession(
        courseName: json['course_name']?.toString() ?? '',
        startDate: json['start_date']?.toString(),
        startTime: json['start_time']?.toString(),
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
  });

  final String courseId;
  final String courseName;

  factory RequiredCourseItem.fromJson(Map<String, dynamic> json) =>
      RequiredCourseItem(
        courseId: json['course_id']?.toString() ?? '',
        courseName: json['course_name']?.toString() ?? json['name']?.toString() ?? '',
      );
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

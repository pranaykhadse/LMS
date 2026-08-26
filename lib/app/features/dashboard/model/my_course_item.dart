import 'package:lms/app/core/utils/format_utils.dart';

class MyCoursesResult {
  const MyCoursesResult({required this.total, required this.courses});
  final int total;
  final List<MyCourseItem> courses;

  factory MyCoursesResult.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : <String, dynamic>{};
    final rawCourses = payload['my_courses'] is List
        ? payload['my_courses'] as List
        : const [];
    return MyCoursesResult(
      total: _asInt(json['total_courses']),
      courses: rawCourses
          .whereType<Map>()
          .map((m) => MyCourseItem.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

class MyCourseItem {
  const MyCourseItem({
    required this.courseId,
    required this.courseName,
    required this.progress,
    required this.displayRating,
    required this.averageRating,
    required this.ratingCount,
    this.logo,
    this.nextSession,
  });

  final int courseId;
  final String courseName;
  final int progress;
  final bool displayRating;
  final double averageRating;
  final int ratingCount;
  final String? logo;
  final DateTime? nextSession;

  factory MyCourseItem.fromJson(Map<String, dynamic> json) {
    final logo = json['logo']?.toString().trim() ?? '';
    return MyCourseItem(
      courseId: _asInt(json['course_id']),
      courseName: json['course_name']?.toString() ?? '',
      progress: _asInt(json['progress']),
      displayRating: json['display_rating'] == true ||
          json['display_rating']?.toString() == '1' ||
          json['display_rating']?.toString().toLowerCase() == 'true',
      averageRating: _asDouble(json['average_rating']),
      ratingCount: _asInt(json['rating_count']),
      logo: logo.isNotEmpty ? logo : null,
      nextSession: json['next_session']?.toString().parseApiUtc(),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

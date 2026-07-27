import 'package:lms/app/features/dashboard/model/dashboard.dart';

class ViewCompetencyResult {
  const ViewCompetencyResult({
    required this.learningPathId,
    required this.learningPathName,
    required this.competency,
    required this.competencyType,
    required this.totalCourses,
    required this.courses,
  });

  final int learningPathId;
  final String learningPathName;
  final String competency;
  final String competencyType;
  final int totalCourses;
  final List<DashboardCourse> courses;

  factory ViewCompetencyResult.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : <String, dynamic>{};
    return ViewCompetencyResult(
      learningPathId: _asInt(payload['learning_path_id']),
      learningPathName: payload['learning_path_name']?.toString() ?? '',
      competency: payload['competency']?.toString() ?? '',
      competencyType: payload['competency_type']?.toString() ?? '',
      totalCourses: _asInt(payload['total_courses']),
      courses: (payload['courses'] as List? ?? [])
          .whereType<Map>()
          .map((m) => DashboardCourse.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

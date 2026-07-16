import 'package:lms/app/features/dashboard/model/dashboard.dart';

class LearningPath {
  const LearningPath({
    required this.id,
    required this.name,
    required this.groupId,
    required this.totalCourses,
    required this.courses,
  });

  final int id;
  final String name;
  final int groupId;
  final int totalCourses;
  final List<DashboardCourse> courses;

  String? get thumbnail => courses.isNotEmpty ? courses.first.logo : null;

  factory LearningPath.fromJson(Map<String, dynamic> json) {
    return LearningPath(
      id: _asInt(json['learning_path_id']),
      name: json['learning_path_name']?.toString() ?? '',
      groupId: _asInt(json['group_id']),
      totalCourses: _asInt(json['total_courses']),
      courses: (json['courses'] as List? ?? [])
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

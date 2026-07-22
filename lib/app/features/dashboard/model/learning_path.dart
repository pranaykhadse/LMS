import 'package:lms/app/features/dashboard/model/dashboard.dart';

class LearningPath {
  const LearningPath({
    required this.id,
    required this.name,
    required this.groupId,
    required this.groupName,
    required this.totalCourses,
    required this.courses,
    required this.competencies,
  });

  final int id;
  final String name;
  final int groupId;
  final String groupName;
  final int totalCourses;
  final List<DashboardCourse> courses;
  final List<LearningPathCompetency> competencies;

  String? get thumbnail => courses.isNotEmpty ? courses.first.logo : null;

  factory LearningPath.fromJson(Map<String, dynamic> json) {
    return LearningPath(
      id: _asInt(json['learning_path_id']),
      name: json['learning_path_name']?.toString() ?? '',
      groupId: _asInt(json['group_id']),
      groupName: json['group_name']?.toString() ?? '',
      totalCourses: _asInt(json['total_courses']),
      courses: (json['courses'] as List? ?? [])
          .whereType<Map>()
          .map((m) => DashboardCourse.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      competencies: (json['competencies'] as List? ?? [])
          .whereType<Map>()
          .map((m) => LearningPathCompetency.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

class LearningPathCompetency {
  const LearningPathCompetency({
    required this.id,
    required this.name,
    required this.courseNames,
    required this.competencyType,
  });

  final int id;
  final String name;
  final List<String> courseNames;
  final String competencyType;

  factory LearningPathCompetency.fromJson(Map<String, dynamic> json) {
    final rawCourses = json['courses'];
    List<String> courseNames;
    if (rawCourses is List) {
      courseNames = rawCourses
          .map((c) => c is Map
              ? (c['course_name'] ?? c['name'] ?? '').toString()
              : c.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (rawCourses is String && rawCourses.isNotEmpty) {
      courseNames = rawCourses.split(',').map((s) => s.trim()).toList();
    } else {
      courseNames = [];
    }
    return LearningPathCompetency(
      id: _asInt(json['competency_id'] ?? json['id']),
      name: json['competency_name']?.toString() ?? json['name']?.toString() ?? '',
      courseNames: courseNames,
      competencyType: json['competency_type']?.toString() ?? json['type']?.toString() ?? '',
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

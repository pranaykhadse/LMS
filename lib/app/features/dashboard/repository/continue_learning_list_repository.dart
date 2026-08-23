import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';

class ContinueLearningListItem {
  const ContinueLearningListItem({
    required this.courseId,
    required this.classId,
    required this.courseName,
    required this.className,
    required this.date,
    required this.status,
    required this.action,
    required this.resumeUrl,
  });

  final int courseId;
  final int classId;
  final String courseName;
  final String className;
  final String date;
  final String status;
  final String action;
  final String? resumeUrl;

  factory ContinueLearningListItem.fromJson(Map<String, dynamic> json) {
    return ContinueLearningListItem(
      courseId: _asInt(json['course_id']),
      classId: _asInt(json['class_id']),
      courseName: json['course_name']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      action: json['action']?.toString() ?? 'Resume',
      resumeUrl: json['resume_url']?.toString(),
    );
  }
}

class ContinueLearningListResult {
  const ContinueLearningListResult({
    required this.totalCourses,
    required this.page,
    required this.pages,
    required this.perPage,
    required this.courses,
  });

  final int totalCourses;
  final int page;
  final int pages;
  final int perPage;
  final List<ContinueLearningListItem> courses;

  factory ContinueLearningListResult.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : <String, dynamic>{};
    return ContinueLearningListResult(
      totalCourses: _asInt(json['total_courses']),
      page: _asInt(json['page']),
      pages: _asInt(json['pages']),
      perPage: _asInt(json['per_page']),
      courses: (payload['courses'] as List? ?? [])
          .whereType<Map>()
          .map((m) => ContinueLearningListItem.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class ContinueLearningListRepository with RepoNetworkHelper {
  ContinueLearningListRepository(this.config);

  static final provider = Provider<ContinueLearningListRepository>((ref) {
    return ContinueLearningListRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<ContinueLearningListResult> fetch({
    required int userId,
    int page = 1,
    int perPage = 10,
  }) async {
    final response = await getRequest(
      'lms-screen/continue-learning',
      queryParameters: {'user_id': userId, 'page': page, 'limit': perPage},
      cacheType: RequestCacheType.none,
    );
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Unable to load in-progress courses.');
    }
    return ContinueLearningListResult.fromJson(data);
  }
}

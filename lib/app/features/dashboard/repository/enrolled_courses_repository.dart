import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';

class EnrolledCoursesResult {
  const EnrolledCoursesResult({required this.totalCourses, required this.courses});
  final int totalCourses;
  final List<DashboardCourse> courses;

  factory EnrolledCoursesResult.fromJson(Map<String, dynamic> json) {
    return EnrolledCoursesResult(
      totalCourses: _asInt(json['total_courses']),
      courses: (json['payload'] as List? ?? [])
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

class EnrolledCoursesRepository with RepoNetworkHelper {
  EnrolledCoursesRepository(this.config);

  static final provider = Provider<EnrolledCoursesRepository>((ref) {
    return EnrolledCoursesRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<EnrolledCoursesResult> fetch({
    required int userId,
    int page = 1,
    int perPage = 5,
  }) async {
    final response = await getRequest(
      'lms-screen/enrolled-courses',
      queryParameters: {'user_id': userId, 'page': page, 'limit': perPage},
      cacheType: RequestCacheType.none,
    );
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Unable to load enrolled courses.');
    }
    return EnrolledCoursesResult.fromJson(data);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';

class CompletedCoursesResult {
  const CompletedCoursesResult({required this.total, required this.courses});
  final int total;
  final List<DashboardCourse> courses;

  factory CompletedCoursesResult.fromJson(Map<String, dynamic> json) {
    return CompletedCoursesResult(
      total: _asInt(json['total']),
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

class CompletedCoursesRepository with RepoNetworkHelper {
  CompletedCoursesRepository(this.config);

  static final provider = Provider<CompletedCoursesRepository>((ref) {
    return CompletedCoursesRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<CompletedCoursesResult> fetch({
    required int userId,
    int page = 1,
    int perPage = 5,
  }) async {
    final response = await getRequest(
      'lms-screen/completed-courses',
      queryParameters: {'user_id': userId, 'page': page, 'limit': perPage},
      cacheType: RequestCacheType.none,
    );
    final data = Map<String, dynamic>.from(response as Map);
    // ignore: avoid_print
    print('COMPLETED_COURSES_RAW: $data');
    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Unable to load completed courses.');
    }
    return CompletedCoursesResult.fromJson(data);
  }
}

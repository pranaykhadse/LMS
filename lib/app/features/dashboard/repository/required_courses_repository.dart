import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';

class RequiredCoursesResult {
  const RequiredCoursesResult({
    required this.total,
    required this.pages,
    required this.page,
    required this.courses,
  });
  final int total;
  final int pages;
  final int page;
  final List<DashboardCourse> courses;

  factory RequiredCoursesResult.fromJson(Map<String, dynamic> json) {
    return RequiredCoursesResult(
      total: _asInt(json['total']),
      pages: _asInt(json['pages']),
      page: _asInt(json['page']),
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

class RequiredCoursesRepository with RepoNetworkHelper {
  RequiredCoursesRepository(this.config);

  static final provider = Provider<RequiredCoursesRepository>((ref) {
    return RequiredCoursesRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<RequiredCoursesResult> fetch({
    required int userId,
    int page = 1,
    int limit = 10,
    String type = 'required',
  }) async {
    final response = await getRequest(
      'lms-screen/required-courses',
      queryParameters: {
        'user_id': userId,
        'page': page,
        'limit': limit,
        'type': type,
      },
      cacheType: RequestCacheType.none,
    );
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Unable to load required courses.');
    }
    return RequiredCoursesResult.fromJson(data);
  }
}

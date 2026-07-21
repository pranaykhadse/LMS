import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';

class DevelopmentPlanResult {
  const DevelopmentPlanResult({required this.total, required this.courses});
  final int total;
  final List<DashboardCourse> courses;

  factory DevelopmentPlanResult.fromJson(Map<String, dynamic> json) {
    return DevelopmentPlanResult(
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

class DevelopmentPlanRepository with RepoNetworkHelper {
  DevelopmentPlanRepository(this.config);

  static final provider = Provider<DevelopmentPlanRepository>((ref) {
    return DevelopmentPlanRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<DevelopmentPlanResult> fetch({
    required int userId,
    int page = 1,
    int perPage = 5,
  }) async {
    final response = await getRequest(
      'lms-screen/development-plan',
      queryParameters: {'user_id': userId, 'page': page, 'limit': perPage},
      cacheType: RequestCacheType.none,
    );
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Unable to load development plan.');
    }
    return DevelopmentPlanResult.fromJson(data);
  }
}

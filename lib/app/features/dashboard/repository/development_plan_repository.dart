import 'package:dio/dio.dart' show Headers, Options;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';

class NonCoursePlanResult {
  const NonCoursePlanResult({required this.success, this.message});
  final bool success;
  final String? message;
}

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

  /// POST lms-screen/non-course-development-plan, form-urlencoded.
  /// request=add + value=<name> creates a new non-course plan item.
  /// user_id is admin-only (acting on behalf of another user) and omitted
  /// here - the logged-in user is resolved from the auth token, same as
  /// course register/cancel and item redeem.
  Future<NonCoursePlanResult> addCustomPlanItem({required String name}) async {
    try {
      final response = await post(
        'lms-screen/non-course-development-plan',
        data: {'request': 'add', 'value': name},
        options: Options(contentType: Headers.formUrlEncodedContentType),
        cacheType: RequestCacheType.none,
      );
      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      if (data['status']?.toString() != '1') {
        return NonCoursePlanResult(
          success: false,
          message: data['message']?.toString() ?? 'Unable to add plan item.',
        );
      }
      return NonCoursePlanResult(success: true, message: data['message']?.toString());
    } catch (e) {
      return NonCoursePlanResult(success: false, message: e.toString());
    }
  }
}

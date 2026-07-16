import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';

class DevPlanActionResult {
  const DevPlanActionResult({required this.success, this.planId, this.message});
  final bool success;
  final int? planId;
  final String? message;
}

class DevelopmentPlanActionRepository with RepoNetworkHelper {
  DevelopmentPlanActionRepository(this.config);

  static final provider = Provider<DevelopmentPlanActionRepository>((ref) {
    return DevelopmentPlanActionRepository(
      ref.watch(ServerProvider.repoConfigProvider),
    );
  });

  @override
  final RepoNetworkConfig config;

  Future<DevPlanActionResult> addToDevPlan({
    required int userId,
    required int courseId,
  }) async {
    try {
      final response = await post(
        'lms-screen/development-plan',
        data: {'user_id': userId, 'course_id': courseId},
        cacheType: RequestCacheType.none,
      );
      final data =
          response is Map
              ? Map<String, dynamic>.from(response)
              : <String, dynamic>{};
      final planId = _asIntOrNull(
        data['plan_id'] ?? data['id'] ?? data['development_plan_id'],
      );
      return DevPlanActionResult(success: true, planId: planId);
    } catch (e) {
      return DevPlanActionResult(success: false, message: e.toString());
    }
  }

  Future<DevPlanActionResult> removeFromDevPlan({
    required int userId,
    required int courseId,
    int? planId,
  }) async {
    try {
      final body = <String, dynamic>{'user_id': userId, 'course_id': courseId};
      if (planId != null) body['plan_id'] = planId;
      await deleteRequest('lms-screen/development-plan', data: body);
      return const DevPlanActionResult(success: true);
    } catch (e) {
      return DevPlanActionResult(success: false, message: e.toString());
    }
  }
}

int? _asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

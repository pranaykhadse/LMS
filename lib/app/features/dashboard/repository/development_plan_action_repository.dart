import 'package:dio/dio.dart' show Headers, Options;
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

  // Single endpoint for add/remove/switch, distinguished by the `action`
  // form field — not separate routes/HTTP methods. Body must be
  // application/x-www-form-urlencoded (formData params), not JSON. `user_id`
  // is admin-only (to manage another user's plan); the current user's own
  // plan is resolved from the auth token, so it's omitted here.
  Future<DevPlanActionResult> _sendAction({
    required int courseId,
    required String action,
  }) async {
    final body = {'course_id': courseId, 'action': action};
    try {
      final response = await post(
        'lms-screen/development-plan-course',
        data: body,
        options: Options(contentType: Headers.formUrlEncodedContentType),
        cacheType: RequestCacheType.none,
      );
      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      if (data['status']?.toString() != '1') {
        return DevPlanActionResult(
          success: false,
          message: data['message']?.toString(),
        );
      }
      final payload = data['payload'] is Map
          ? Map<String, dynamic>.from(data['payload'] as Map)
          : data;
      final planId = _asIntOrNull(
        payload['plan_id'] ?? payload['id'] ?? payload['development_plan_id'],
      );
      return DevPlanActionResult(
        success: true,
        planId: planId,
        message: data['message']?.toString(),
      );
    } catch (e) {
      return DevPlanActionResult(success: false, message: e.toString());
    }
  }

  Future<DevPlanActionResult> addToDevPlan({required int courseId}) {
    return _sendAction(courseId: courseId, action: 'add');
  }

  Future<DevPlanActionResult> removeFromDevPlan({required int courseId}) {
    return _sendAction(courseId: courseId, action: 'remove');
  }
}

int? _asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

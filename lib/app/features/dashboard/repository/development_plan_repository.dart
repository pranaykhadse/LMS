import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart' show Headers, Options;
import 'package:flutter/foundation.dart';
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
    if (kDebugMode) {
      // Temporary: figure out which raw field actually distinguishes
      // "not enrolled" from "0% complete" - see DashboardCourse.notEnrolled.
      // Printed as one line per item (not the whole response) so it isn't
      // cut off by the terminal, and only the one item under investigation
      // is dumped as pretty JSON so every key on it is visible.
      final items = data['payload'] is List ? data['payload'] as List : const [];
      for (final item in items) {
        if (item is! Map) continue;
        debugPrint('[DevelopmentPlanRepository] item: ${item['course_name'] ?? item['name']} -> keys=${item.keys.toList()}');
      }
      final target = items
          .whereType<Map>()
          .where((item) => item['course_name']?.toString() == 'Course Feedback')
          .firstOrNull;
      if (target != null) {
        const encoder = JsonEncoder.withIndent('  ');
        debugPrint('[DevelopmentPlanRepository] Course Feedback full item:\n${encoder.convert(target)}');
      }
    }
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

  /// POST lms-screen/non-course-development-plan, form-urlencoded.
  /// request=update + value=<percentage 0-100> + id=<non-course item id>
  /// updates the completion percentage of an existing non-course plan item.
  Future<NonCoursePlanResult> updateCustomPlanItem({
    required int id,
    required int percentage,
  }) async {
    try {
      final response = await post(
        'lms-screen/non-course-development-plan',
        data: {'request': 'update', 'value': percentage, 'id': id},
        options: Options(contentType: Headers.formUrlEncodedContentType),
        cacheType: RequestCacheType.none,
      );
      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      if (data['status']?.toString() != '1') {
        return NonCoursePlanResult(
          success: false,
          message: data['message']?.toString() ?? 'Unable to update plan item.',
        );
      }
      return NonCoursePlanResult(success: true, message: data['message']?.toString());
    } catch (e) {
      return NonCoursePlanResult(success: false, message: e.toString());
    }
  }
}

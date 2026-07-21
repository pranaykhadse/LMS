import 'package:dio/dio.dart' show Headers, Options;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/courses/model/course_join_detail.dart';

class CourseEnrollResult {
  const CourseEnrollResult({required this.success, this.message});
  final bool success;
  final String? message;
}

class CourseJoinDetailRepository with RepoNetworkHelper {
  CourseJoinDetailRepository(this.config);

  static final provider = Provider<CourseJoinDetailRepository>((ref) {
    return CourseJoinDetailRepository(
      ref.watch(ServerProvider.repoConfigProvider),
    );
  });

  @override
  final RepoNetworkConfig config;

  Future<CourseJoinDetail> fetch({
    required int userId,
    required int courseId,
  }) async {
    final response = await getRequest(
      'lms-screen/join-course-detail',
      queryParameters: {'user_id': userId, 'id': courseId},
      cacheType: RequestCacheType.none,
    );
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(
        data['message']?.toString() ?? 'Unable to load course details.',
      );
    }
    return CourseJoinDetail.fromJson(data);
  }

  /// Whole-course enrollment (POST lms-screen/register-course, form-urlencoded).
  /// Only `course_id` is sent - `user_id` is admin-only (registering someone
  /// else) and is resolved from the auth token for the current user.
  Future<CourseEnrollResult> register({required int courseId}) async {
    try {
      final response = await post(
        'lms-screen/register-course',
        data: {'course_id': courseId},
        options: Options(contentType: Headers.formUrlEncodedContentType),
        cacheType: RequestCacheType.none,
      );
      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      if (data['status']?.toString() != '1') {
        return CourseEnrollResult(
          success: false,
          message: data['message']?.toString() ?? 'Unable to enroll in this course.',
        );
      }
      return CourseEnrollResult(success: true, message: data['message']?.toString());
    } catch (e) {
      return CourseEnrollResult(success: false, message: e.toString());
    }
  }
}

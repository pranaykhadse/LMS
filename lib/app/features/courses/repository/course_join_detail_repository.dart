import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/courses/model/course_join_detail.dart';

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
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/courses/model/course_catalog.dart';

class CourseCatalogRepository with RepoNetworkHelper {
  CourseCatalogRepository(this.config);

  static final provider = Provider<CourseCatalogRepository>((ref) {
    return CourseCatalogRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<CourseCatalogResponse> fetch({
    required int userId,
    int page = 1,
    String? search,
    String? skillId,
  }) async {
    final response = await getRequest(
      'lms-screen/course-catalog',
      queryParameters: {
        'user_id': userId,
        'page': page,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (skillId != null && skillId.isNotEmpty) 'skill_id': skillId,
      },
      cacheType: RequestCacheType.fetch,
    );
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Unable to load courses.');
    }
    return CourseCatalogResponse.fromJson(data);
  }
}

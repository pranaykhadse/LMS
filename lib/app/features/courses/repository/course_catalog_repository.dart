import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/courses/model/course_catalog.dart';

class CourseCatalogRepository with RepoNetworkHelper {
  CourseCatalogRepository(this.config);

  static final provider = Provider<CourseCatalogRepository>((ref) {
    return CourseCatalogRepository(
      ref.watch(ServerProvider.repoConfigProvider),
    );
  });

  @override
  final RepoNetworkConfig config;

  Future<CourseCatalogResponse> fetch({
    required int userId,
    Map<String, int> groupPages = const {},
    String? search,
    String? skillId,
    int perPage = 5,
  }) async {
    final queryParameters = {
      'user_id': userId,
      'per_page': perPage,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (skillId != null && skillId.isNotEmpty) 'skill_id': skillId,
      for (final entry in groupPages.entries)
        'group_page[${entry.key}]': entry.value,
    };
    debugPrint('[CourseCatalogRepository] fetch query=$queryParameters');
    final response = await getRequest(
      'lms-screen/course-catalog',
      queryParameters: queryParameters,
      cacheType: RequestCacheType.none,
    );
    debugPrint('[CourseCatalogRepository] raw response (${response.runtimeType}): $response');
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Unable to load courses.');
    }
    final parsed = CourseCatalogResponse.fromJson(data);
    debugPrint('[CourseCatalogRepository] parsed groups=${parsed.groups.length} '
        'flatCourses=${parsed.courses.length} total=${parsed.total}');
    return parsed;
  }

  Future<CourseCatalogResponse> search({
    required int userId,
    int page = 1,
    String? name,
    String? skillId,
    String? behaviorId,
  }) async {
    final response = await getRequest(
      'lms-screen/search-result',
      queryParameters: {
        'user_id': userId,
        'page': page,
        'limit': 5,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if ((skillId ?? behaviorId) != null &&
            (skillId ?? behaviorId)!.isNotEmpty)
          'skill_id': skillId ?? behaviorId,
      },
      cacheType: RequestCacheType.none,
    );
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(
        data['message']?.toString() ?? 'Unable to search courses.',
      );
    }
    return CourseCatalogResponse.fromJson(data);
  }
}

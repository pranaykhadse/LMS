import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/paginated_fetch.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/learning_path.dart';

class LearningPathsRepository with RepoNetworkHelper {
  LearningPathsRepository(this.config);

  static final provider = Provider<LearningPathsRepository>((ref) {
    return LearningPathsRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<List<LearningPath>> fetch({
    required int userId,
    String? name,
  }) async {
    return fetchAllPages<LearningPath>(
      fetchPage: (page, perPage) async {
        final response = await getRequest(
          'lms-screen/learning-paths-catalog',
          queryParameters: {
            'user_id': userId,
            'page': page,
            'limit': perPage,
            if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
          },
          cacheType: RequestCacheType.none,
        );
        final data = Map<String, dynamic>.from(response as Map);
        if (data['status']?.toString() != '1') {
          throw Exception(
            data['message']?.toString() ?? 'Unable to load learning paths.',
          );
        }
        return (data['payload'] as List? ?? [])
            .whereType<Map>()
            .map((m) => LearningPath.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      },
    );
  }
}

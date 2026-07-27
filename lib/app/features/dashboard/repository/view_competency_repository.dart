import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/view_competency.dart';

class ViewCompetencyRepository with RepoNetworkHelper {
  ViewCompetencyRepository(this.config);

  static final provider = Provider<ViewCompetencyRepository>((ref) {
    return ViewCompetencyRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  /// GET lms-screen/view-competency - returns every course belonging to a
  /// single competency within a learning path.
  Future<ViewCompetencyResult> fetch({
    required int userId,
    required int learningPathId,
    required String competency,
  }) async {
    final response = await getRequest(
      'lms-screen/view-competency',
      queryParameters: {
        'user_id': userId,
        'learning_path_id': learningPathId,
        'competency': competency,
      },
      cacheType: RequestCacheType.none,
    );
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(
        data['message']?.toString() ?? 'Unable to load competency details.',
      );
    }
    return ViewCompetencyResult.fromJson(data);
  }
}

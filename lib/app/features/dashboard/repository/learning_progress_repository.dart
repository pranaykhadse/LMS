import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/learning_progress_model.dart';

class LearningProgressRepository with RepoNetworkHelper {
  LearningProgressRepository(this.config);

  static final provider = Provider<LearningProgressRepository>((ref) {
    return LearningProgressRepository(
      ref.watch(ServerProvider.repoConfigProvider),
    );
  });

  @override
  final RepoNetworkConfig config;

  Future<LearningProgressData> fetch({required int userId}) async {
    final raw = await getRequest(
      'lms-screen/learning-progress',
      queryParameters: {'user_id': userId},
      cacheType: RequestCacheType.none,
    );
    final json =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return LearningProgressData.fromJson(json);
  }
}

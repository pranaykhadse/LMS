import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/badge.dart';

class BadgesRepository with RepoNetworkHelper {
  BadgesRepository(this.config);

  static final provider = Provider<BadgesRepository>((ref) {
    return BadgesRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<BadgesResult> fetch({required int userId}) async {
    final response = await getRequest(
      'lms-screen/user-badges',
      queryParameters: {'user_id': userId},
      cacheType: RequestCacheType.none,
    );
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Unable to load badges.');
    }
    return BadgesResult.fromJson(data);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';

class DashboardRepository with RepoNetworkHelper {
  DashboardRepository(this.config);

  static final provider = Provider<DashboardRepository>((ref) {
    return DashboardRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<DashboardResponse> fetch({required int userId}) async {
    final response = await getRequest(
      'lms-screen/dashboard',
      queryParameters: {'user_id': userId},
      cacheType: RequestCacheType.none,
    );
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(
        data['message']?.toString() ?? 'Unable to load dashboard.',
      );
    }
    return DashboardResponse.fromJson(data);
  }
}

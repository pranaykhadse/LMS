import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/paginated_fetch.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/redeem_history_item.dart';

class RedeemHistoryRepository with RepoNetworkHelper {
  RedeemHistoryRepository(this.config);

  static final provider = Provider<RedeemHistoryRepository>((ref) {
    return RedeemHistoryRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<RedeemHistoryResult> fetch({required int userId}) async {
    var total = 0;
    final items = await fetchAllPages<RedeemHistoryItem>(
      fetchPage: (page, perPage) async {
        final response = await getRequest(
          'lms-screen/redeem-history-user',
          queryParameters: {
            'user_id': userId,
            'page': page,
            'limit': perPage,
          },
          cacheType: RequestCacheType.none,
        );
        final data = Map<String, dynamic>.from(response as Map);
        if (data['status']?.toString() != '1') {
          throw Exception(
            data['message']?.toString() ?? 'Unable to load redeem history.',
          );
        }
        final result = RedeemHistoryResult.fromJson(data);
        total = result.total;
        return result.items;
      },
    );
    return RedeemHistoryResult(total: total, items: items);
  }
}

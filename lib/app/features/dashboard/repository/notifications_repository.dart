import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/paginated_fetch.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/notification_model.dart';

class NotificationsRepository with RepoNetworkHelper {
  NotificationsRepository(this.config);

  static final provider = Provider<NotificationsRepository>((ref) {
    return NotificationsRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<List<NotificationItem>> fetch({required int userId}) async {
    return fetchAllPages<NotificationItem>(
      fetchPage: (page, perPage) async {
        final raw = await getRequest(
          'lms-screen/notifications',
          queryParameters: {
            'user_id': userId,
            'page': page,
            'limit': perPage,
          },
          cacheType: RequestCacheType.none,
        );
        final json = raw is Map ? raw : <String, dynamic>{};
        final payload = json['payload'];
        final list = payload is List ? payload : const [];
        return list
            .whereType<Map>()
            .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
    );
  }
}

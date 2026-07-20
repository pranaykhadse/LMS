import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    debugPrint('[NotificationsRepository] fetching for user_id=$userId, '
        'baseUrl=$baseUrl, url=${baseUrl}lms-screen/notifications');
    final raw = await getRequest(
      'lms-screen/notifications',
      queryParameters: {'user_id': userId},
      cacheType: RequestCacheType.none,
    );
    debugPrint('[NotificationsRepository] raw response (${raw.runtimeType}): $raw');
    final json = raw is Map ? raw : <String, dynamic>{};
    final payload = json['payload'];
    debugPrint('[NotificationsRepository] payload (${payload.runtimeType}): $payload');
    final list = payload is List ? payload : const [];
    final parsed = list
        .whereType<Map>()
        .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    debugPrint('[NotificationsRepository] parsed ${parsed.length} notifications');
    return parsed;
  }
}

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/paginated_fetch.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/local_storage_provider.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/notification_model.dart';

class NotificationsRepository with RepoNetworkHelper {
  NotificationsRepository(this.config, this.storage);

  static final provider = Provider<NotificationsRepository>((ref) {
    return NotificationsRepository(
      ref.watch(ServerProvider.repoConfigProvider),
      ref.watch(LocalStorage.provider),
    );
  });

  @override
  final RepoNetworkConfig config;
  final LocalStorage storage;

  String _cacheKey(int userId) => 'notifications_cache_$userId';

  /// Every successful fetch is cached locally (same pattern as
  /// CourseJoinDetailRepository) so notifications are still available with
  /// the manual "Offline Mode" toggle on, or with no real connectivity -
  /// getRequest() fails fast rather than actually hitting the network in
  /// either case (see RepoNetworkHelper.isOffline), so this falls straight
  /// through to the cache without waiting on a real timeout. Only surfaces
  /// the error if there's nothing cached to fall back to.
  /// POST lms-screen/notifications/mark-all-read
  /// Marks all notifications belonging to the authenticated user as read.
  Future<void> markAllRead() async {
    await post(
      'lms-screen/notifications/mark-all-read',
      data: {},
    );
  }

  /// POST lms-screen/notifications/{id}/read
  /// Marks a specific notification as read.
  Future<void> markOneRead(String id) async {
    await post(
      'lms-screen/notifications/$id/read',
      data: {},
    );
  }

  /// DELETE lms-screen/notifications/{id}
  /// Deletes a specific notification.
  Future<void> deleteOne(String id) async {
    await deleteRequest('lms-screen/notifications/$id');
  }

  Future<List<NotificationItem>> fetch({required int userId}) async {
    try {
      final items = await fetchAllPages<NotificationItem>(
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
      await storage.setString(
        _cacheKey(userId),
        jsonEncode(items.map((e) => e.toJson()).toList()),
      );
      return items;
    } catch (error) {
      final cachedRaw = await storage.getString(_cacheKey(userId));
      if (cachedRaw != null) {
        try {
          final cachedList = jsonDecode(cachedRaw) as List;
          return cachedList
              .whereType<Map>()
              .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } catch (_) {
          // Cached data is unreadable - fall through to the original error.
        }
      }
      rethrow;
    }
  }
}

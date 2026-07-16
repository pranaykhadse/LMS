import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/inventory_item.dart';

class ItemInventoryRepository with RepoNetworkHelper {
  ItemInventoryRepository(this.config);

  static final provider = Provider<ItemInventoryRepository>((ref) {
    return ItemInventoryRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<InventoryResult> fetch({required int userId}) async {
    final response = await getRequest(
      'lms-screen/item-inventory',
      queryParameters: {'user_id': userId},
      cacheType: RequestCacheType.none,
    );
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Unable to load inventory.');
    }
    return InventoryResult.fromJson(data);
  }

  Future<void> redeem({required int userId, required int itemId}) async {
    final response = await post(
      'lms-screen/item-inventory/redeem',
      data: {'user_id': userId, 'item_id': itemId},
      cacheType: RequestCacheType.none,
    );
    final data = response is Map
        ? Map<String, dynamic>.from(response as Map)
        : <String, dynamic>{};
    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Failed to redeem item.');
    }
  }
}

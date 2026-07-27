import 'package:dio/dio.dart' show Headers, Options;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/inventory_item.dart';

class RedeemResult {
  const RedeemResult({required this.success, this.message, this.remainingPoints});
  final bool success;
  final String? message;
  final int? remainingPoints;
}

class ItemInventoryRepository with RepoNetworkHelper {
  ItemInventoryRepository(this.config);

  static final provider = Provider<ItemInventoryRepository>((ref) {
    return ItemInventoryRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<InventoryResult> fetch({
    required int userId,
    int page = 1,
    int perPage = 10,
    String? search,
  }) async {
    final response = await getRequest(
      'lms-screen/item-inventory',
      queryParameters: {
        'user_id': userId,
        'page': page,
        'limit': perPage,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
      cacheType: RequestCacheType.none,
    );
    final data = Map<String, dynamic>.from(response as Map);
    if (data['status']?.toString() != '1') {
      throw Exception(data['message']?.toString() ?? 'Unable to load inventory.');
    }
    return InventoryResult.fromJson(data);
  }

  /// POST lms-screen/redeem-item, form-urlencoded. `user_id` is not part of
  /// the documented form fields - the logged-in user is resolved from the
  /// auth token, same as course register/cancel.
  Future<RedeemResult> redeem({
    required int itemId,
    required String address,
    String? note,
  }) async {
    try {
      final body = <String, dynamic>{
        'item_id': itemId,
        'address': address,
      };
      if (note != null && note.isNotEmpty) body['note'] = note;
      final response = await post(
        'lms-screen/redeem-item',
        data: body,
        options: Options(contentType: Headers.formUrlEncodedContentType),
        cacheType: RequestCacheType.none,
      );
      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      if (data['status']?.toString() != '1') {
        return RedeemResult(
          success: false,
          message: data['message']?.toString() ?? 'Failed to redeem item.',
        );
      }
      final payload = data['payload'] is Map
          ? Map<String, dynamic>.from(data['payload'] as Map)
          : <String, dynamic>{};
      return RedeemResult(
        success: true,
        message: data['message']?.toString(),
        remainingPoints: _asIntOrNull(payload['remaining_points']),
      );
    } catch (e) {
      return RedeemResult(success: false, message: e.toString());
    }
  }
}

int? _asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

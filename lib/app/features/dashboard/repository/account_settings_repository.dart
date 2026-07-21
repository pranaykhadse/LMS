import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/user_profile_detail.dart';

class AccountSettingsUpdateResult {
  const AccountSettingsUpdateResult({required this.success, this.message});
  final bool success;
  final String? message;
}

class AccountSettingsRepository with RepoNetworkHelper {
  AccountSettingsRepository(this.config);

  static final provider = Provider<AccountSettingsRepository>((ref) {
    return AccountSettingsRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  Future<UserProfileDetail> fetch({required int userId}) async {
    final raw = await getRequest(
      'user-profile/$userId',
      cacheType: RequestCacheType.none,
    );
    final json = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return UserProfileDetail.fromJson(json);
  }

  Future<AccountSettingsUpdateResult> update({
    required int userId,
    required Map<String, dynamic> body,
  }) async {
    debugPrint('[AccountSettingsRepository] PUT user-profile/$userId body=$body');
    try {
      final raw = await put(
        'user-profile/$userId',
        data: body,
        cacheType: RequestCacheType.none,
      );
      debugPrint('[AccountSettingsRepository] response (${raw.runtimeType}): $raw');
      final data =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      if (data['status']?.toString() == '0') {
        return AccountSettingsUpdateResult(
          success: false,
          message: data['message']?.toString(),
        );
      }
      return AccountSettingsUpdateResult(
        success: true,
        message: data['message']?.toString(),
      );
    } catch (e) {
      debugPrint('[AccountSettingsRepository] update error: $e');
      return AccountSettingsUpdateResult(success: false, message: e.toString());
    }
  }

  Future<AccountSettingsUpdateResult> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final raw = await put(
        'user-profile/change-password',
        data: {
          'user_id': userId,
          'old_password': oldPassword,
          'new_password': newPassword,
        },
        cacheType: RequestCacheType.none,
      );
      final data =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      if (data['status']?.toString() == '0') {
        return AccountSettingsUpdateResult(
          success: false,
          message: data['message']?.toString() ?? 'Unable to change password.',
        );
      }
      return AccountSettingsUpdateResult(
        success: true,
        message: data['message']?.toString(),
      );
    } catch (e) {
      return AccountSettingsUpdateResult(success: false, message: e.toString());
    }
  }
}

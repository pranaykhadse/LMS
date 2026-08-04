import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
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
    final detail = UserProfileDetail.fromJson(json);
    if (kDebugMode) {
      debugPrint(
        '[AccountSettingsRepository.fetch] userId=$userId '
        'avatarPath=${detail.profile.avatarPath} '
        'avatarBaseUrl=${detail.profile.avatarBaseUrl} '
        'avatarUrl=${detail.profile.avatarUrl}',
      );
    }
    return detail;
  }

  Future<AccountSettingsUpdateResult> update({
    required int userId,
    required Map<String, dynamic> body,
  }) async {
    try {
      final raw = await put(
        'user-profile/$userId',
        data: body,
        cacheType: RequestCacheType.none,
      );
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
      return AccountSettingsUpdateResult(success: false, message: e.toString());
    }
  }

  /// POST user-profile/upload-avatar - multipart upload that replaces the
  /// authenticated user's avatar. No user_id is sent: that query param is
  /// admin-only (upload on behalf of someone else), which this app has no
  /// UI for - a normal user's own token is enough to identify whose avatar
  /// to replace.
  Future<AccountSettingsUpdateResult> uploadAvatar({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final raw = await post(
        'user-profile/upload-avatar',
        data: {
          'avatar': MultipartFile.fromBytes(bytes, filename: filename),
        },
        cacheType: RequestCacheType.none,
      );
      if (kDebugMode) debugPrint('[AccountSettingsRepository.uploadAvatar] raw=$raw');
      final data =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      if (data['status']?.toString() == '0') {
        return AccountSettingsUpdateResult(
          success: false,
          message: data['message']?.toString() ?? 'Unable to upload avatar.',
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

import 'package:dio/dio.dart';
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

class AvatarUploadResult {
  const AvatarUploadResult({
    required this.success,
    this.message,
    this.avatarPath,
    this.avatarBaseUrl,
  });
  final bool success;
  final String? message;
  // Straight from the upload response's own payload - lets the caller
  // patch just the avatar fields onto the profile it already has, instead
  // of re-fetching (and replacing) the whole profile, which would risk
  // every other field on screen visibly refreshing too.
  final String? avatarPath;
  final String? avatarBaseUrl;
}

class AccountSettingsRepository with RepoNetworkHelper {
  AccountSettingsRepository(this.config);

  static final provider = Provider<AccountSettingsRepository>((ref) {
    return AccountSettingsRepository(
      ref.watch(ServerProvider.repoConfigProvider),
    );
  });

  @override
  final RepoNetworkConfig config;

  Future<UserProfileDetail> fetch({required int userId}) async {
    final raw = await getRequest(
      'user-profile/$userId',
      cacheType: RequestCacheType.none,
    );
    final json =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    if (kDebugMode) {
      // Temporary: checking whether country_iso round-trips through a save.
      debugPrint(
        '[AccountSettingsRepository] GET user-profile/$userId -> '
        'country_code=${json['country_code']}, country_iso=${json['country_iso']}',
      );
    }
    return UserProfileDetail.fromJson(json);
  }

  Future<AccountSettingsUpdateResult> update({
    required int userId,
    required Map<String, dynamic> body,
  }) async {
    if (kDebugMode) {
      // Temporary: checking whether country_iso round-trips through a save.
      debugPrint(
        '[AccountSettingsRepository] PUT user-profile/$userId body '
        'country_code=${body['country_code']}, country_iso=${body['country_iso']}',
      );
    }
    try {
      final raw = await put(
        'user-profile/$userId',
        data: body,
        cacheType: RequestCacheType.none,
      );
      final data =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      if (kDebugMode) {
        debugPrint(
          '[AccountSettingsRepository] PUT response: '
          'status=${data['status']}, message=${data['message']}, '
          'country_code=${data['country_code']}, country_iso=${data['country_iso']}, '
          'payload=${data['payload']}',
        );
      }
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
  Future<AvatarUploadResult> uploadAvatar({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint(
          '[AccountSettingsRepository] POST user-profile/upload-avatar '
          'filename=$filename bytes=${bytes.length}',
        );
      }
      final raw = await post(
        'user-profile/upload-avatar',
        data: {'avatar': MultipartFile.fromBytes(bytes, filename: filename)},
        cacheType: RequestCacheType.none,
      );
      if (kDebugMode) {
        // The exact server response — the toast only ever showed the top-
        // level `message`, which can be a generic fallback string that
        // hides the actual reason (a validation error on a specific
        // field, a size/type limit, an auth issue, ...). Logging the
        // whole raw body surfaces whatever detail the server actually
        // sent back.
        debugPrint(
          '[AccountSettingsRepository] upload-avatar raw response: $raw',
        );
      }
      final data =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      if (data['status']?.toString() == '0') {
        return AvatarUploadResult(
          success: false,
          message: data['message']?.toString() ?? 'Unable to upload avatar.',
        );
      }
      final payload =
          data['payload'] is Map
              ? Map<String, dynamic>.from(data['payload'])
              : <String, dynamic>{};
      return AvatarUploadResult(
        success: true,
        message: data['message']?.toString(),
        avatarPath: payload['avatar_path']?.toString(),
        avatarBaseUrl: payload['avatar_base_url']?.toString(),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AccountSettingsRepository] upload-avatar threw: $e');
        // A DioException's own `.response` (status code + server body) is
        // the actual diagnostic payload for an HTTP-level failure (4xx/5xx,
        // a validation error body, ...) — `e.toString()` alone usually
        // only says "DioException [bad response]: ...", not what the
        // server actually said.
        if (e is DioException) {
          debugPrint(
            '[AccountSettingsRepository] upload-avatar DioException: '
            'type=${e.type} statusCode=${e.response?.statusCode} '
            'responseData=${e.response?.data}',
          );
        }
        debugPrint('[AccountSettingsRepository] upload-avatar stack: $st');
      }
      return AvatarUploadResult(success: false, message: e.toString());
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

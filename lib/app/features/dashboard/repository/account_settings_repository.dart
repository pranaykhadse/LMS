import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/dashboard/model/user_profile_detail.dart';

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
}

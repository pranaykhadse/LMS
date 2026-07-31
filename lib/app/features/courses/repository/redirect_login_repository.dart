import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/server_provider.dart';

class RedirectLoginRepository with RepoNetworkHelper {
  RedirectLoginRepository(this.config);

  static final provider = Provider<RedirectLoginRepository>((ref) {
    return RedirectLoginRepository(ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  /// GET user-profile/redirect-login-link?redirectUrl=<url>, Bearer-authed
  /// with the app's own API token. Returns a URL that logs the current user
  /// in and redirects to [redirectUrl] - used so Attend Class's in-app
  /// WebView opens already authenticated instead of showing a login form.
  /// Returns null on any failure so the caller can fall back to opening
  /// [redirectUrl] directly.
  Future<String?> getLoginLink(String redirectUrl) async {
    if (kDebugMode) {
      debugPrint('[RedirectLoginRepository] requesting login link for redirectUrl=$redirectUrl');
    }
    try {
      final response = await getRequest(
        'user-profile/redirect-login-link',
        queryParameters: {'redirectUrl': redirectUrl},
        cacheType: RequestCacheType.none,
      );
      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      final link = data['login_link']?.toString();
      if (kDebugMode) {
        debugPrint('[RedirectLoginRepository] response=$data');
        debugPrint('[RedirectLoginRepository] resolved login_link=$link');
      }
      return (link == null || link.isEmpty) ? null : link;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RedirectLoginRepository] getLoginLink failed: $e');
      }
      return null;
    }
  }
}

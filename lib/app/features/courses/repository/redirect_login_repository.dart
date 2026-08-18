import 'package:flutter/foundation.dart';
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
    try {
      debugPrint('=== REDIRECT LOGIN API ===');
      debugPrint('Endpoint: ${baseUrl}user-profile/redirect-login-link');
      debugPrint('redirectUrl param: $redirectUrl');
      final response = await getRequest(
        'user-profile/redirect-login-link',
        queryParameters: {'redirectUrl': redirectUrl},
        cacheType: RequestCacheType.none,
      );
      debugPrint('Raw response: $response');
      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      final link = data['login_link']?.toString();
      debugPrint('Extracted login_link: $link');
      debugPrint('=========================');
      return (link == null || link.isEmpty) ? null : link;
    } catch (e) {
      debugPrint('getLoginLink exception: $e');
      return null;
    }
  }
}

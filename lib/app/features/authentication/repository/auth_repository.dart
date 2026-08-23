
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';

class AuthRepository with RepoNetworkHelper {
  static final provider = Provider<AuthRepository>((ref) {
    return AuthRepository(config: ref.watch(ServerProvider.repoConfigProvider));
  });

  @override
  final RepoNetworkConfig config;

  AuthRepository({required this.config});
  Future<AuthState> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await post(
      'auth/login',
      data: {"email": email, "password": password},
      cacheType: RequestCacheType.none,
    );

    return AuthState.fromJson(response);
  }

  /// Exchanges the auto_login_token captured at the last real login for a
  /// fresh access token, without needing the user's password again. Used
  /// whenever an API call comes back 401 because the access token expired
  /// mid-session - see RepoNetworkConfig.refreshToken.
  Future<AuthState> autoLogin({
    required String email,
    required String autoLoginToken,
  }) async {
    final response = await post(
      "auth/auto-login",
      data: {"email": email, "auto_login_token": autoLoginToken},
      cacheType: RequestCacheType.none,
    );
    return AuthState.fromJson(response);
  }

  Future<AuthState> validateToken(AuthState params) async {
    try {
      final response = await getRequest(
        "allcourse",
        cacheType: RequestCacheType.none,
      );

      return params;
    } catch (e) {}
    final token = params.user?.autoLoginToken;
    var email = params.user?.email;
    if (token == null || email == null) throw UnauthorizedException();
    final response = await post(
      "auth/auto-login",
      data: {"email": email, "auto_login_token": params.user?.autoLoginToken},
      cacheType: RequestCacheType.none,
    );
    
    return AuthState.fromJson(response);
  }
}

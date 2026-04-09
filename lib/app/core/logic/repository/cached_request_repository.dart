import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/server_provider.dart';

import '../../../features/authentication/app_state/auth_state_provider.dart';
import '../../provider/internet_connection_provider.dart';
import '../../provider/request_cache_provider.dart';
import 'repo_network_helper.dart';

class CachedRequestRepository with RepoNetworkHelper {
  static final provider = Provider<CachedRequestRepository>((ref) {
    return CachedRequestRepository(
      config: RepoNetworkConfig(
        url: ref.watch(ServerProvider.serverUrl),
        authToken: ref.watch(AuthStateNotifier.provider)?.token,
        connectionProvider: ref.watch(InternetConnectionProvider.provider),
      ),
    );
  });

  @override
  RepoNetworkConfig config;
  CachedRequestRepository({required this.config});

  Future<void> sendCachedRequest(CachableRequest request) async {
    final response = await post(
      request.path,
      data: request.body,
      cacheType: RequestCacheType.none,
    );
    print("Sent request: ${request.path}:   $response");
  }
}

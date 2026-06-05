import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/request_cache_provider.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';

class ServerProvider {
  /// The API origin. Override at build time via --dart-define:
  ///   flutter run  --dart-define=SERVER_URL=https://app.trainingpipeline.com/api/web/
  ///   flutter build macos --dart-define=SERVER_URL=https://app.trainingpipeline.com/api/web/
  static const _envUrl     = String.fromEnvironment('SERVER_URL');
  static const _defaultUrl = 'https://staging.trainingpipeline.com/api/web/';

  static final serverUrl = Provider<String>((ref) {
    return _envUrl.isNotEmpty ? _envUrl : _defaultUrl;
  });

  static final repoConfigProvider = StateProvider<RepoNetworkConfig>((ref) {
    return RepoNetworkConfig(
      url: ref.watch(serverUrl),
      authToken: ref.watch(AuthStateNotifier.provider)?.token,
      // timezone:
      //     ref.watch(AuthStateNotifier.provider)?.sessionData?.timezoneHeader,
      connectionProvider: ref.watch(InternetConnectionProvider.provider),
      requestCacheProvider: ref.watch(RequestCacheProvider.provider),
    );
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
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

  static final repoConfigProvider = Provider<RepoNetworkConfig>((ref) {
    return RepoNetworkConfig(
      url: ref.watch(serverUrl),
      // Deliberately `.select((s) => s?.token)` rather than watching the
      // whole AuthStateNotifier: the token string is all the network layer
      // needs, and watching the whole notifier rebuilt every repo/viewmodel
      // that depends on this config on ANY AuthState change — including an
      // avatar upload, which syncs a new profile via
      // AuthStateNotifier.updateProfile() (a fresh AuthState identity even
      // though the token itself is unchanged). That rebuild tears down and
      // recreates the currently-open Account Settings viewmodel, whose
      // fresh fetch() can then flash the whole screen to the "Unable to
      // load your profile" error. Selecting only the token means repos only
      // rebuild when the token actually changes (login/logout/token-refresh).
      authToken: ref.watch(
        AuthStateNotifier.provider.select((s) => s?.token),
      ),
      connectionProvider: ref.watch(InternetConnectionProvider.provider),
      requestCacheProvider: ref.watch(RequestCacheProvider.provider),
      // Deliberately ref.read (not watch) via a live closure, not a frozen
      // bool: flipping the toggle must be checked by the NEXT request a
      // screen makes, but must NOT tear down/recreate already-successful
      // repository & viewmodel providers (which ref.watch here would do,
      // wiping already-loaded screens back to a loading/error state the
      // instant the toggle flips, before the user even navigates anywhere).
      isManualOffline: () => ref.read(OfflineModeNotifier.provider),
      // Deliberately ref.read for the same reason as isManualOffline above -
      // a closure that always calls through to the current notifier
      // instance, not a value frozen at the time this config was built.
      refreshToken: () =>
          ref.read(AuthStateNotifier.provider.notifier).refreshAccessToken(),
    );
  });
}

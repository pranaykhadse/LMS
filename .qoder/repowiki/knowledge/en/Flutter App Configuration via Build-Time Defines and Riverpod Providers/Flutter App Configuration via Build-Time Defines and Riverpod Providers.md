---
kind: configuration_system
name: Flutter App Configuration via Build-Time Defines and Riverpod Providers
category: configuration_system
scope:
    - '**'
source_files:
    - lib/app/core/provider/server_provider.dart
    - lib/app/core/logic/repository/repo_network_helper.dart
    - lib/main.dart
    - lib/app_module.dart
    - lib/app/core/localization/translate.dart
    - assets/translations/en.json
    - pubspec.yaml
    - flutter_launcher_icons.yaml
---

## What system/approach is used

The Flutter application uses a minimal, build-time configuration approach centered on `String.fromEnvironment` combined with the Riverpod dependency-injection layer. There is no runtime `.env` file loader, no YAML/JSON config files consumed at startup, and no feature-flag framework. The only externalized runtime value is the API server URL, which is supplied via the `--dart-define=SERVER_URL=...` flag passed to `flutter run` or `flutter build`. All other configuration (network timeouts, headers, offline behavior, caching strategy) is hard-coded into the `RepoNetworkConfig` / `RepoNetworkHelper` classes.

## Key files and packages

- `lib/app/core/provider/server_provider.dart` — single source of truth for the API origin; reads `SERVER_URL` from `String.fromEnvironment('SERVER_URL')`, falls back to a hardcoded staging URL (`https://staging.trainingpipeline.com/api/web/`), and exposes it as a Riverpod `Provider<String>` plus a `RepoNetworkConfig` provider.
- `lib/app/core/logic/repository/repo_network_helper.dart` — defines `RepoNetworkConfig` (url, authToken, connectionProvider, requestCacheProvider, isManualOffline, refreshToken) and the `RepoNetworkHelper` mixin that builds a Dio client with base URL, default JSON content-type, 20s connect/receive and 30s send timeouts, an offline-mode check, optional request caching, and a one-shot 401 refresh-token retry interceptor.
- `lib/main.dart` — app bootstrap: initializes `MediaKit`, `EasyLocalization`, runs cleanup of stale viewing temp files, then wires `EasyLocalization` → `ProviderScope` → `ModularApp` → `MyApp`.
- `lib/app_module.dart` — Flutter Modular root module wiring routes `/`, `/auth`, `/home`.
- `assets/translations/en.json` + `lib/app/core/localization/translate.dart` — localization configuration via `easy_localization`; supported locales declared in `AppTranslations.languages` and path set to `assets/translations`.
- `pubspec.yaml` — declares dependencies (`dio`, `hive_flutter`, `easy_localization`, `flutter_modular`, `flutter_riverpod`, `flutter_inappwebview`, `media_kit`, …), registers assets (`assets/images/`, `assets/translations/`), and configures code generation via `flutter_gen` outputting to `lib/gen/`.
- `flutter_launcher_icons.yaml` — build-time asset generation config for launcher icons across Android, iOS, Web, Windows, macOS.
- Platform shells (`android/gradle.properties`, `ios/Runner/Info.plist`, `macos/Runner/Configs/*.xcconfig`, `linux/`, `windows/`, `web/manifest.json`) — platform-specific build/runtime metadata but no application-level configuration values.

## Architecture and conventions

1. **Single configurable entry point**: The only injectable runtime value is `SERVER_URL`. It is read once at compile time via `String.fromEnvironment('SERVER_URL')` and exposed through a Riverpod `Provider<String>` so any consumer can `ref.watch(serverUrl)` without knowing how the value was obtained.

2. **Configuration object pattern**: `RepoNetworkConfig` bundles all network-related configuration (base URL, auth token, connectivity provider, cache provider, manual-offline toggle, token-refresh callback). Consumers implement `RepoNetworkHelper` and expose `RepoNetworkConfig get config;`, keeping per-repository configuration uniform.

3. **Riverpod as DI container**: Providers are defined under `lib/app/core/provider/` and composed in `ServerProvider.repoConfigProvider`, which wires together `serverUrl`, `AuthStateNotifier` (for token), `InternetConnectionProvider`, `RequestCacheProvider`, and `OfflineModeNotifier`. This centralizes cross-cutting concerns instead of scattering them across repositories.

4. **Hardcoded defaults with override path**: Default values live next to their usage (e.g., `_defaultUrl = 'https://staging.trainingpipeline.com/api/web/'`). Overrides are always opt-in via `--dart-define`; there is no fallback chain like env-file → shared-preferences → remote config.

5. **No runtime config loading**: No `package:flutter_dotenv`, no `SharedPreferences`-based settings store for app-level config, no remote feature flags. Offline mode is toggled via an in-app notifier (`OfflineModeNotifier`) rather than a persistent setting.

6. **Build-time asset/config generation**: Icons and generated constants are produced by `flutter_launcher_icons` and `flutter_gen_runner` during the build step, not loaded at runtime.

## Conventions and constraints

- **API origin must be supplied per build flavor** using `--dart-define=SERVER_URL=...` (documented in comments in `server_provider.dart`); if omitted, the app silently falls back to the staging URL.
- **All HTTP clients go through `RepoNetworkHelper`** — direct Dio usage outside this mixin bypasses the configured base URL, auth header, timeout policy, offline detection, and 401 retry logic.
- **Default headers are enforced centrally**: `RepoNetworkConfig.header` always sets `content-type: application/json`; multipart requests explicitly override via `optionsFor()` to avoid a stale JSON content-type when sending `FormData`.
- **Timeouts are fixed** in the Dio `BaseOptions` inside `RepoNetworkHelper.dio` (connect/receive 20s, send 30s); they are not exposed as configurable parameters.
- **Offline behavior is dual-sourced**: `isOffline` returns true when either `config.isManualOffline()` (user toggle) or `config.connectionProvider.isConnected == false`; both paths short-circuit to cached/offline handling before any network call.
- **Localization is static**: Supported locales are declared as a constant list in `AppTranslations.languages` and the translation bundle lives under `assets/translations/`; new languages require editing both the Dart constant and adding a corresponding JSON file.
- **Platform-specific configuration lives in native manifests** (`Info.plist`, `AndroidManifest.xml`, `*.xcconfig`, `gradle.properties`); the Dart layer does not read these at runtime.
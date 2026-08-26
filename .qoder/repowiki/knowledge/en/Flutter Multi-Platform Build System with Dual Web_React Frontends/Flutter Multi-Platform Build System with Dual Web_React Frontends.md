---
kind: build_system
name: Flutter Multi-Platform Build System with Dual Web/React Frontends
category: build_system
scope:
    - '**'
source_files:
    - pubspec.yaml
    - android/build.gradle.kts
    - android/app/build.gradle.kts
    - android/gradle.properties
    - ios/Podfile
    - macos/Podfile
    - macos/Runner/Configs/Release.xcconfig
    - windows/flutter/CMakeLists.txt
    - linux/CMakeLists.txt
    - flutter_launcher_icons.yaml
    - analysis_options.yaml
    - run_chrome_dev.bat
    - web/manifest.json
    - devtools_options.yaml
---

## What system/approach is used

This repository is a **Flutter multi-platform application** that builds native binaries for Android, iOS, Linux, Windows, and macOS from a single Dart codebase under `lib/`, plus a **separate React + Tailwind dashboard** under `src/` built independently via its own toolchain. There is no custom Makefile or CI pipeline in the repo; build orchestration relies on Flutter's standard tooling (`flutter build`, `flutter run`) augmented by platform-specific Gradle/CMake/Xcode configurations and a few helper scripts.

## Key files and packages

- **`pubspec.yaml`** — central dependency manifest declaring SDK `^3.7.2`, all runtime dependencies (Riverpod, Dio, Hive, media_kit, flutter_inappwebview, etc.), dev dependencies (`flutter_lints`, `mockito`, `build_runner`, `flutter_gen_runner`, `flutter_launcher_icons`, `change_app_package_name`), asset registration (`assets/images/`, `assets/translations/`), and `flutter_gen` output to `lib/gen/`. Version is declared as `1.0.5+5` and is propagated to Android/iOS via `flutter.versionName` / `flutter.versionCode`.
- **`android/build.gradle.kts`** — root Gradle script that redirects all build outputs into the shared `../build/` directory so Android artifacts coexist with Flutter's cross-platform build tree; enforces `JavaVersion.VERSION_11` and Kotlin JVM target 11.
- **`android/app/build.gradle.kts`** — app module applying `com.android.application`, `kotlin-android`, and `dev.flutter.flutter-gradle-plugin`; reads compile/target/minSdk from Flutter tooling; release build currently signs with debug keys (commented TODO).
- **`ios/Podfile`** and **`macos/Podfile`** — CocoaPods manifests pinned to minimum platforms `iOS 13.0` and `macOS 10.15`; both disable CocoaPods analytics (`COCOAPODS_DISABLE_STATS=true`) to avoid network latency during `flutter build`; use `use_frameworks!` and call `flutter_install_all_*_pods`.
- **`windows/flutter/CMakeLists.txt`**, **`linux/CMakeLists.txt`** — generated Flutter CMake configs that invoke `tool_backend.bat` / `tool_backend.sh` to compile the Dart AOT snapshot and link the Flutter engine wrapper; Linux sets binary name `lms`, application ID `com.example.lms`, and installs AOT library only for non-Debug builds.
- **`macos/Runner/Configs/Release.xcconfig`** — includes Flutter's release xcconfig plus a project `Warnings.xcconfig`.
- **`flutter_launcher_icons.yaml`** — drives icon generation across Android (`launcher_icon`, min SDK 21), iOS (removes alpha), web (PWA icons), Windows (48px), and macOS from a single source `assets/images/app_icon.png`.
- **`analysis_options.yaml`** — activates `package:flutter_lints/flutter.yaml` and excludes generated/platform directories (`build/**`, `android/**`, `ios/**`, `web/**`, `windows/**`, `macos/**`, `linux/**`) from static analysis.
- **`run_chrome_dev.bat`** — convenience launcher that starts a local CORS proxy (`dev_cors_proxy.js`) then runs `flutter run -d chrome --web-port=8000 --dart-define=SERVER_URL=http://localhost:8081/api/web/`.
- **`web/manifest.json`** — PWA manifest for the Flutter web target (icons at 192/512, maskable variants).
- **`devtools_options.yaml`** — empty extensions list, leaving DevTools defaults.

## Architecture and conventions

- **Single-source Dart UI**: All mobile/desktop targets share one `lib/` tree; platform differences are isolated in `android/`, `ios/`, `linux/`, `macos/`, `windows/` shells. The Flutter tool generates per-target plugin registrants and CMake/Gradle/Xcode glue.
- **Shared build output**: The Android Gradle root script rewrites every subproject's build directory to `../../build/<subproject>`, consolidating all artifacts under the repo-level `build/` folder alongside Flutter's generated outputs.
- **Version propagation**: `pubspec.yaml` version string is consumed by `android/app/build.gradle.kts` via `flutter.versionName` / `flutter.versionCode`, which maps to Android `versionName`/`versionCode` and iOS `CFBundleShortVersionString`/`CFBundleVersion` (documented in pubspec comments).
- **Build types**: Debug, Profile, Release are the three modes across all platforms. Linux CMake defaults to `Debug` unless overridden; Release builds install the AOT `.so`/`.dylib`/`.dll` artifact.
- **Separate React dashboard**: The `src/` directory contains an independent React application (Tailwind CSS, shadcn/ui primitives) that is not part of the Flutter build graph; it would be built via its own npm/yarn toolchain outside this repo's Flutter configuration.
- **Asset & codegen pipeline**: Assets are declared in `pubspec.yaml` and processed by `flutter_gen_runner` into `lib/gen/`; icons are regenerated via `flutter_launcher_icons` from a single PNG source.

## Conventions and constraints

- **SDK pinning**: Dart SDK constrained to `^3.7.2` in `pubspec.yaml`; Android compile/target options are sourced from Flutter tooling rather than hard-coded values.
- **Java/Kotlin baseline**: Android modules enforce Java 11 source/target compatibility and Kotlin JVM target 11.
- **Minimum OS versions**: iOS minimum `13.0`, macOS minimum `10.15`, Android min SDK `21` (via `flutter_launcher_icons` config); these are enforced by the respective platform Podfiles and Gradle configs.
- **Signing convention**: Release builds currently fall back to the debug signing config (explicitly noted as a TODO in `android/app/build.gradle.kts`), meaning production signing must be added before publishing.
- **Lint exclusion policy**: Generated and platform shell directories are excluded from `flutter analyze` to keep lint noise out of developer feedback.
- **CocoaPods performance**: Both iOS and macOS Podfiles set `ENV['COCOAPODS_DISABLE_STATS'] = 'true'` to suppress synchronous analytics calls that slow down `pod install`.
- **Web development workflow**: Chrome debugging uses a local Node CORS proxy started via `run_chrome_dev.bat`, with the backend URL injected through `--dart-define=SERVER_URL=...` so the same Flutter web build can target different servers without code changes.
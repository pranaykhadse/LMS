---
kind: dependency_management
name: Multi-Platform Dependency Management (Flutter pub, CocoaPods, Gradle)
category: dependency_management
scope:
    - '**'
source_files:
    - pubspec.yaml
    - pubspec.lock
    - ios/Podfile
    - ios/Podfile.lock
    - macos/Podfile
    - macos/Podfile.lock
    - android/build.gradle.kts
    - android/app/build.gradle.kts
    - android/settings.gradle.kts
---

## Overview

This repository is a multi-platform project that combines a Flutter application (mobile + desktop) with a separate React web dashboard under `src/`. Dependency management is split across three independent ecosystems — each platform owns its own dependency declaration and lockfile.

## Flutter App (`pubspec.yaml` + `pubspec.lock`)

- **Package manager**: Dart/Flutter `pub`, declared in the root `pubspec.yaml`.
- **Versioning style**: Caret ranges (`^x.y.z`) for all third-party packages, pinning only minor/patch updates. The SDK constraint is `sdk: ^3.7.2`.
- **Lockfile**: `pubspec.lock` is committed to version control; it pins every transitive dependency to an exact version and SHA-256 hash from `https://pub.dev` (hosted source). This makes builds deterministic across machines.
- **Publishing**: `publish_to: 'none'` explicitly prevents accidental publishing to pub.dev, treating the app as a private package.
- **Dependency categories** are grouped by comments into Core (`flutter_riverpod`, `flutter_modular`, `dio`, `hive_flutter`), Design (`cupertino_icons`, `google_fonts`, `hugeicons`, `lucide_icons`), Localization (`easy_localization`, `internet_connection_checker_plus`, `flutter_styled_toast`, `table_calendar`, `form_validator`), WebView (`flutter_inappwebview` — chosen over `webview_flutter` because of macOS opaque hit-test support), Media (`media_kit` stack instead of `video_player`/`chewie` for WebM/VP9 software decoding on iOS), PDF (`pdfrx`), Image picker (`image_picker`), Country flags (`country_flags`).
- **Dev dependencies**: `flutter_lints`, `mockito`, `build_runner`, `flutter_gen_runner`, `flutter_launcher_icons`, `change_app_package_name` — used only during development/build-time code generation.
- **No vendoring**: Dependencies are resolved remotely from pub.dev; there is no local `packages/` directory or git-submodule vendoring strategy.
- **Asset bundling**: Static assets live under `assets/images/` and `assets/translations/en.json` and are declared in the `flutter.assets` section of `pubspec.yaml`.

## iOS & macOS Native Dependencies (CocoaPods)

- **Manager**: CocoaPods via `ios/Podfile` and `macos/Podfile`.
- **Minimum platforms**: iOS 13.0, macOS 10.15.
- **Analytics disabled**: `ENV['COCOAPODS_DISABLE_STATS'] = 'true'` is set in both Podfiles to avoid synchronous network calls during install.
- **Flutter integration**: Both Podfiles call `flutter_ios_podfile_setup` / `flutter_macos_podfile_setup` and then `flutter_install_all_ios_pods` / `flutter_install_all_macos_pods`, which auto-installs native plugins declared in `pubspec.yaml` (e.g., `flutter_inappwebview`, `url_launcher`). No extra pods are manually declared beyond what Flutter plugins require.
- **Lockfile**: `ios/Podfile.lock` and `macos/Podfile.lock` are present and committed, pinning pod versions per target (`Runner`, `RunnerTests`).
- **Frameworks mode**: `use_frameworks!` is enabled so plugins can be linked as dynamic frameworks.

## Android Native Dependencies (Gradle)

- **Manager**: Gradle Kotlin DSL (`android/build.gradle.kts`, `android/app/build.gradle.kts`, `android/settings.gradle.kts`).
- **Repositories**: `google()` and `mavenCentral()` are declared at the allprojects level — no custom/private Maven repositories are configured.
- **Build directory**: Customized to a shared `../../build` directory at the repo root to consolidate outputs.
- **Plugin resolution**: Managed through Flutter's generated plugin registrant (`GeneratedPluginRegistrant.java`); no explicit `implementation` lines for Flutter plugins appear in the top-level Gradle file.

## React Web Dashboard (`src/`)

- **No `package.json` found** in the repository tree. The React UI under `src/app/components/ui/` consists of hand-written shadcn/ui-style components (accordion, alert-dialog, avatar, badge, button, card, carousel, chart, checkbox, collapsible, command, context-menu, dialog, drawer, dropdown-menu, form, hover-card, input-otp, input, label, menubar, navigation-menu, pagination, popover, progress, radio-group, resizable, scroll-area, select, separator, sheet, sidebar, skeleton, slider, sonner, switch, table, tabs, textarea, toggle-group, toggle, tooltip, plus `use-mobile.ts` and `utils.ts`).
- Because there is no `package.json`, npm/yarn/pnpm dependency declarations are not tracked in this repository snapshot. The UI appears to be implemented as self-contained components without external JS library imports (no `@/` or `~/` path aliases were detected in the scanned files).

## Conventions Observed

1. **Per-platform manifests**: Each ecosystem declares its own dependencies in its canonical file (`pubspec.yaml`, `Podfile`, Gradle scripts); there is no cross-repo dependency sharing.
2. **Lockfiles committed**: `pubspec.lock`, `ios/Podfile.lock`, and `macos/Podfile.lock` are version-controlled to ensure reproducible builds.
3. **Public registries only**: All dependencies resolve from public sources (pub.dev, CocoaPods trunk, Google/Maven Central); no private registry or `GOOGLE_PRIVATE_REGISTRY` / `GOPRIVATE` configuration was found.
4. **Caret versioning**: Dart dependencies use `^` ranges, allowing safe minor/patch upgrades while preventing breaking changes.
5. **Flutter-managed native deps**: iOS/macOS native dependencies are not hand-edited in Podfiles — they are pulled in automatically via Flutter's `flutter_install_all_*_pods` helpers based on `pubspec.yaml` entries.
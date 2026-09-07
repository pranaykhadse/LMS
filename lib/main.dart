import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:media_kit/media_kit.dart';
import 'package:lms/app/core/localization/translate.dart';
import 'package:lms/app/features/courses/viewmodel/file_cache_view_model.dart';

import 'app/core/design/app_theme.dart';
import 'app/core/navigation/root_navigator.dart';
import 'app_module.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  // Best-effort: remove any decrypted-for-viewing temp copies left behind
  // by a previous run that crashed or was force-quit before cleaning up
  // after itself.
  unawaited(FileCacheViewModel.clearAllViewing());
  runApp(
    EasyLocalization(
      supportedLocales: AppTranslations.languages,
      path: 'assets/translations',
      fallbackLocale: AppTranslations.languages.first,
      child: ProviderScope(
        child: ModularApp(
          module: AppModule(),
          debugMode: kDebugMode,
          child: const MyApp(),
        ),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StyledToast(
      locale: context.locale,
      textStyle: const TextStyle(fontSize: 14, color: Colors.white),
      child: MaterialApp.router(
        routerConfig: Modular.routerConfig,
        title: 'Leadership Edge Live',
        theme: AppTheme.getLight(context),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        debugShowCheckedModeBanner: false,
        // Adds one extra, permanent outermost Navigator (see
        // root_navigator.dart) purely so full-screen dialogs can anchor
        // on a Navigator that's guaranteed to span the whole screen.
        // `routerConfig` doesn't expose a `navigatorKey` param of its own
        // to reach the Navigator flutter_modular's RouterDelegate creates
        // internally, and that internal Navigator only covers whichever
        // nested module (e.g. the home/courses module) is currently
        // active anyway.
        //
        // `child` (the actual routed app content, always current) is
        // rendered directly as a Stack sibling, NOT inside this
        // Navigator's own route - `onGenerateRoute` only fires once, when
        // the Navigator first mounts, so a route built from a
        // closure-captured `child` would freeze on whatever screen was
        // showing at that moment and never update as Modular navigates.
        // This Navigator's own base route is instead a permanent, empty,
        // IgnorePointer placeholder (so it never blocks taps meant for
        // the real content underneath) that dialogs get pushed on top of
        // - those later routes are unaffected by the placeholder's
        // IgnorePointer and stay fully interactive as normal.
        builder: (context, child) {
          return Stack(
            children: [
              child!,
              Positioned.fill(
                child: Navigator(
                  key: rootNavigatorKey,
                  onGenerateRoute:
                      (settings) => PageRouteBuilder(
                        settings: settings,
                        opaque: false,
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                        pageBuilder:
                            (context, _, __) =>
                                const IgnorePointer(child: SizedBox.expand()),
                      ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

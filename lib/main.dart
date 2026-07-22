import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:media_kit/media_kit.dart';
import 'package:lms/app/core/localization/translate.dart';

import 'app/core/design/app_theme.dart';
import 'app_module.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await EasyLocalization.ensureInitialized();
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
      ),
    );
  }
}

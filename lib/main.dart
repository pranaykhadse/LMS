import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/localization/translate.dart';
import 'package:lms/app/core/logic/app_global_handlers.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';

import 'app/core/design/app_theme.dart';
import 'app_module.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Register the global 401/403 handler once.
    // Any API call that returns Unauthorized will call logout() and
    // navigate to the login screen instead of showing an error UI.
    AppGlobalHandlers.onUnauthorized = () {
      ref.read(AuthStateNotifier.provider.notifier).logout();
      Modular.to.navigate(AppModule.auth);
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: Modular.routerConfig,
      title: 'Leadership Edge Live',
      theme: AppTheme.getLight(context),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      debugShowCheckedModeBanner: false,
    );
  }
}

import 'package:flutter/material.dart';

/// The app's single true outermost [Navigator] - a plain [Navigator]
/// wrapping the entire routed app (see `MaterialApp.router`'s `builder`
/// in `main.dart`), added purely to host full-screen dialogs/overlays.
///
/// `flutter_modular` registers `/home` as a nested child *module*
/// (`r.module(home, module: CoursesModule())` in `app_module.dart`), which
/// gives that module its own routing scope/Navigator (created internally
/// by Modular's `RouterDelegate`, not reachable via a `navigatorKey` on
/// `MaterialApp.router` alongside `routerConfig`). `showDialog`'s default
/// `useRootNavigator: true` walks up the Navigator ancestor chain from the
/// calling context, but can't cross that module's routing boundary to
/// reach any Navigator above it - so a dialog opened from anywhere inside
/// the home/courses module only got a barrier sized to that module's own
/// routed viewport, not the full screen (confirmed via a live screenshot:
/// the persistent header/nav bar outside that module's content stayed
/// undimmed).
///
/// Any dialog that must cover the entire screen regardless of which
/// module its calling context lives in should use
/// `rootNavigatorKey.currentContext!` instead of the local `context` when
/// calling `showDialog`/`showGeneralDialog`.
final rootNavigatorKey = GlobalKey<NavigatorState>();

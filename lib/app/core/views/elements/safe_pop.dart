import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';

/// Pops the current route if there's something to pop back to. If not
/// (e.g. this screen ended up as the only route in the stack — a stale
/// back button rendered before state settled, or a deep link landed here
/// directly), a raw `Navigator.pop` would empty the app's declarative
/// route stack and leave a black screen instead of navigating anywhere.
/// Falls back to the Dashboard in that case.
void safePop(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  Modular.to.navigate(CoursesModule.construct(CoursesModule.dashboard));
}

/// Screens like Account Settings, Notifications, Redeem History and the
/// Learning Progress viewer are opened with a raw Navigator.push rather
/// than through Modular's own routing, so they sit on top of Modular's
/// declarative page stack as extra imperative history entries — swapping
/// that declarative stack (via Modular.to.navigate/pushNamed) doesn't
/// remove them, so a nav tap would silently do nothing while one of those
/// pages was open. Call before any such navigation to clear them first.
void resetToModularRoot(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
}

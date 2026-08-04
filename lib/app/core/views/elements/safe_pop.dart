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

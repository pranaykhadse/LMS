import 'package:flutter_modular/flutter_modular.dart';
import 'package:lms/app/features/authentication/view/auth_gate.dart';
import 'package:lms/app/features/dashboard/view/dashboard_page.dart';
import 'package:lms/app_module.dart';

import '../view/course_classes_page.dart';
import '../view/courses_page.dart';

class CoursesModule extends Module {
  static const root = "/";
  static const dashboard = "/dashboard";
  static const detail = "/detail";

  static String construct(String path) {
    return AppModule.home + path;
  }

  @override
  void routes(RouteManager r) {
    r.child(
      dashboard,
      child: (context) => const AuthGate(child: DashboardPage()),
    );
    r.child("/", child: (context) => const AuthGate(child: CoursesPage()));
    r.child(
      "$detail/:id",
      child:
          (context) => AuthGate(
            child: CourseClassesPage(courseId: Modular.args.params['id']),
          ),
    );
  }
}

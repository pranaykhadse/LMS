import 'package:flutter_modular/flutter_modular.dart';
import 'package:lms/app_module.dart';

import '../view/course_classes_page.dart';
import '../view/courses_page.dart';

class CoursesModule extends Module {
  static const root = "/";
  static const detail = "/detail";

  static String construct(String path) {
    return AppModule.home + path;
  }

  @override
  void routes(RouteManager r) {
    r.child("/", child: (context) => CoursesPage());
    r.child(
      "$detail/:id",
      child:
          (context) => CourseClassesPage(courseId: Modular.args.params['id']),
    );
  }
}

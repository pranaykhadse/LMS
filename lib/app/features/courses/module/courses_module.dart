import 'package:flutter_modular/flutter_modular.dart';
import 'package:lms/app/core/views/elements/main_shell.dart';
import 'package:lms/app/features/authentication/view/auth_gate.dart';
import 'package:lms/app/features/dashboard/view/completed_courses_page.dart';
import 'package:lms/app/features/dashboard/view/development_plan_page.dart';
import 'package:lms/app/features/dashboard/view/enrolled_courses_page.dart';
import 'package:lms/app/features/dashboard/view/badges_page.dart';
import 'package:lms/app/features/dashboard/view/item_inventory_page.dart';
import 'package:lms/app/features/dashboard/view/learning_paths_page.dart';
import 'package:lms/app/features/dashboard/view/required_courses_page.dart';
import 'package:lms/app/features/dashboard/view/my_courses_page.dart';
import 'package:lms/app_module.dart';

import '../view/course_classes_page.dart';
import '../view/courses_page.dart';

class CoursesModule extends Module {
  static const root = "/";
  static const dashboard = "/dashboard";
  static const detail = "/detail";
  static const myCourses = "/my-courses";
  static const enrolledCourses = "/enrolled-courses";
  static const completedCourses = "/completed-courses";
  static const developmentPlan = "/development-plan";
  static const requiredCourses = "/required-courses";
  static const learningPaths = "/learning-paths";
  static const badges = "/badges";
  static const redeemPoints = "/redeem-points";

  static String construct(String path) {
    return AppModule.home + path;
  }

  @override
  void routes(RouteManager r) {
    r.child(
      dashboard,
      // Desktop's persistent shell for all top-level nav destinations -
      // see main_shell.dart. Mobile still gets DashboardPage's own
      // AppScaffold/AppDrawer (MainShell only overrides the isTablet
      // desktop path; AppScaffold falls through to normal behavior below
      // that width), so this works for both.
      child: (context) => const AuthGate(child: MainShell()),
    );
    r.child(myCourses, child: (context) => const AuthGate(child: MyCoursesPage()));
    r.child(enrolledCourses, child: (context) => const AuthGate(child: EnrolledCoursesPage()));
    r.child(completedCourses, child: (context) => const AuthGate(child: CompletedCoursesPage()));
    r.child(developmentPlan, child: (context) => const AuthGate(child: DevelopmentPlanPage()));
    r.child(requiredCourses, child: (context) => const AuthGate(child: RequiredCoursesPage()));
    r.child(learningPaths, child: (context) => const AuthGate(child: LearningPathsPage()));
    r.child(badges, child: (context) => const AuthGate(child: BadgesPage()));
    r.child(redeemPoints, child: (context) => const AuthGate(child: ItemInventoryPage()));
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

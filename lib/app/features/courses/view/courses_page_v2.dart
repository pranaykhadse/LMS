/// CoursesPageV2 — Course Catalog with exact CSS reference styling.
///
/// CSS applied (in courses_page.dart which this delegates to):
///   div.container:            padding 0 40px
///   div.py-2 .search-blcok:   bg #fff, radius 16px, padding 10px,
///                             shadow 0 4px 20px rgba(0,0,0,0.05),
///                             border 1px #f0f1f5
///   .searchInput:             radius 12px, border 1px #e2e8f0,
///                             bg #f8fafc, 14px, h 42px,
///                             focus border #693D94 bg #fff
///   .sec-title h2.title:      color #693D94, h 48px, flex
///   div#resources:            bg #fff, border 1px #E7E4FF,
///                             radius 14px, padding 30px
///   .modern-course-card:      radius 16px, shadow 0 10px 25px rgba(0,0,0,0.05)
///   .btn-modern-primary:      bg #693D94 hover #5A3480, white, radius 8px
///
/// CoursesPage (courses_page.dart) is kept intact.
/// This file is the entry point used by routing.
library;

import 'package:flutter/widgets.dart';
import 'package:lms/app/features/courses/view/courses_page.dart';

/// Routing entry point for the Course Catalog screen.
/// Delegates to [CoursesPage] which implements the full CSS-matched UI.
class CoursesPageV2 extends StatelessWidget {
  const CoursesPageV2({super.key});

  @override
  Widget build(BuildContext context) => const CoursesPage();
}

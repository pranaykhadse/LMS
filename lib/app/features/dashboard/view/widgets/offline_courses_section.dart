import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/view/widgets/offline_course_action.dart';
import 'package:lms/app/features/courses/viewmodel/offline_view_model.dart';

const _offlinePurple = FigmaTokens.primaryPurple;
const _offlineInk = FigmaTokens.cardTitles;
const _offlineMuted = FigmaTokens.noteBodyText;
const _offlinePink = Color(0xFFB0006D);

/// Whether the app should be showing cached/offline content instead of
/// hitting the live API - the manual "Offline Mode" toggle, or no real
/// connectivity. Same rule Course Catalog uses for its own Offline Courses
/// section (see courses_page.dart).
bool isEffectivelyOffline(WidgetRef ref) {
  final isManualOffline = ref.watch(OfflineModeNotifier.provider);
  final connectionVM = ref.watch(InternetConnectionProvider.provider);
  return isManualOffline || !connectionVM.isConnected;
}

/// The My Courses sub-pages (Enrolled/Completed/Required) equivalent of
/// Course Catalog's "Offline Courses" section - shown instead of the live
/// paginated list while offline, scoped to whichever of the offline-saved
/// courses match [matches] for that particular page (e.g. not yet fully
/// complete for Enrolled, fully complete for Completed, isRequired for
/// Required).
class OfflineCoursesSection extends ConsumerWidget {
  const OfflineCoursesSection({
    super.key,
    required this.matches,
    required this.emptyMessage,
  });

  final bool Function(Course course) matches;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineState = ref.watch(OfflineViewModel.provider).courses;
    switch (offlineState.state) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(child: CircularProgressIndicator(color: _offlinePurple));
      case DataProviderState.error:
        return const Center(
          child: Text(
            'Unable to load offline courses.',
            style: TextStyle(color: _offlineMuted),
          ),
        );
      case DataProviderState.data:
        final courses = (offlineState.data ?? const <Course>[]).where(matches).toList();
        if (courses.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _offlineMuted, fontSize: 14, height: 1.5),
              ),
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Offline Courses',
                style: TextStyle(color: _offlinePink, fontSize: 17, fontWeight: FontWeight.w500),
              ),
            ),
            GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: Responsive.columns(context, phone: 2, tablet: 3, desktop: 4),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.62,
                mainAxisExtent: Responsive.isTablet(context) ? 290 : null,
              ),
              itemCount: courses.length,
              itemBuilder: (ctx, i) => _OfflineCourseCard(course: courses[i]),
            ),
            const AppFooter(),
          ],
        );
    }
  }
}

// ─── Course card ─────────────────────────────────────────────────────────────

class _OfflineCourseCard extends StatelessWidget {
  const _OfflineCourseCard({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final progress = (course.percentage * 100).round();
    final displayRating = course.displayRating == 1;
    final averageRating =
        course.averageRating is num ? (course.averageRating as num).toDouble() : 0.0;
    final ratingCount = course.ratingCount ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 110,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                course.logoLink != null
                    ? Image.network(
                        course.logoLink!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _ImgFallback(),
                      )
                    : const _ImgFallback(),
                Positioned(top: 6, left: 6, child: OfflineCourseButton(course: course)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _offlineInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (displayRating) ...[
                    _StarRow(rating: averageRating, count: ratingCount),
                    const SizedBox(height: 6),
                  ] else
                    const SizedBox(height: 2),
                  if (progress > 0) ...[
                    _ProgressRow(progress: progress),
                    const SizedBox(height: 6),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: HoverBuilder(
                      builder: (context, hovering) => ElevatedButton(
                        onPressed: () => Modular.to.pushNamed(
                          CoursesModule.construct('${CoursesModule.detail}/${course.id}'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              hovering ? FigmaTokens.purpleHover : _offlinePurple,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        child: const Text('View Course'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Progress bar ─────────────────────────────────────────────────────────────

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.progress});
  final int progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 5,
            backgroundColor: const Color(0xFFE8E7F8),
            valueColor: const AlwaysStoppedAnimation<Color>(_offlinePurple),
          ),
        ),
        const SizedBox(height: 3),
        Text('$progress% complete', style: const TextStyle(color: _offlineMuted, fontSize: 10)),
      ],
    );
  }
}

// ─── Star rating ──────────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < rating.floor()) {
            return const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 15);
          }
          if (i < rating) {
            return const Icon(Icons.star_half_rounded, color: Color(0xFFFFC107), size: 15);
          }
          return const Icon(Icons.star_border_rounded, color: Color(0xFFFFC107), size: 15);
        }),
        const SizedBox(width: 4),
        Text(
          '${rating.toStringAsFixed(1)} ($count)',
          style: const TextStyle(color: _offlineMuted, fontSize: 11),
        ),
      ],
    );
  }
}

// ─── Image fallback ───────────────────────────────────────────────────────────

class _ImgFallback extends StatelessWidget {
  const _ImgFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0ECFF),
      alignment: Alignment.center,
      child: const Icon(Icons.school_outlined, color: _offlinePurple, size: 54),
    );
  }
}

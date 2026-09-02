import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/course_image_fallback.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/model/course_join_detail.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/repository/redirect_login_repository.dart';
import 'package:lms/app/features/courses/view/content_view_page.dart';
import 'package:lms/app/features/courses/view/content_viewer/certificate_content_viewer.dart';
import 'package:lms/app/features/courses/view/content_viewer/in_app_webview_page.dart';
import 'package:lms/app/features/courses/view/content_viewer/pdf_content_viewer.dart';
import 'package:lms/app/features/courses/view/content_viewer/video_content_viewer.dart';
import 'package:lms/app/features/courses/view/widgets/class_status_chip.dart';
import 'package:lms/app/features/courses/view/widgets/download_button.dart';
import 'package:lms/app/features/courses/view/widgets/reviews_modal.dart';
import 'package:lms/app/features/courses/viewmodel/course_catalog_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/course_join_detail_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/file_cache_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/roaster_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

bool _watchIsOnline(WidgetRef ref) {
  final isManualOffline = ref.watch(OfflineModeNotifier.provider);
  final connectionVM = ref.watch(InternetConnectionProvider.provider);
  ref.watch(SyncViewModel.provider);
  return !isManualOffline && connectionVM.isConnected;
}

// CSS ref, joinCourse.php embedded V2 design-system tokens over the global
// app.css: `body { font-family:'Outfit','Inter',... !important }` — only
// Inter is actually loaded (blue_base.php), so THIS page renders in Inter,
// not the app-wide Roboto. Also `--text-dark:#111827` (headings/labels,
// was FigmaTokens.cardTitles #1E2939) and `--body-bg:#f4f6fb` (page bg,
// was FigmaTokens.pageBackground #F4F5F7).
const _detailPurple = FigmaTokens.primaryPurple;
const _detailPurple2 = FigmaTokens.gradientEnd;
const _detailInk = Color(0xFF111827);
const _detailMuted = FigmaTokens.noteBodyText;
const _detailBackground = Color(0xFFF4F6FB);

class CourseClassesPage extends ConsumerStatefulWidget {
  const CourseClassesPage({super.key, this.courseId});
  final String? courseId;

  @override
  ConsumerState<CourseClassesPage> createState() => _CourseClassesPageState();
}

class _CourseClassesPageState extends ConsumerState<CourseClassesPage> {
  bool _redirectingUnauthorized = false;
  bool _shownNotFoundToast = false;

  @override
  Widget build(BuildContext context) {
    final courseId = int.tryParse(widget.courseId ?? '') ?? 0;
    final state = ref.watch(CourseJoinDetailViewModel.provider(courseId));

    if (!_redirectingUnauthorized && isUnauthorizedError(state.error)) {
      _redirectingUnauthorized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        redirectToLoginOnSessionExpired(context, ref);
      });
    }

    if (!_shownNotFoundToast && isCourseNotFoundError(state.error)) {
      _shownNotFoundToast = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Toast.danger(context, 'Course has been deleted by the Admin.');
      });
    }

    return AppScaffold(
      backgroundColor: _detailBackground,
      selectedLabel: 'Course Catalog',
      onBack: () => _goBackToCatalog(context, ref),
      onRefresh:
          () =>
              ref
                  .read(CourseJoinDetailViewModel.provider(courseId).notifier)
                  .fetch(),
      body: _DetailBody(courseId: courseId, state: state),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.courseId, required this.state});

  final int courseId;
  final DataState<CourseJoinDetail> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state.state) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(
          child: CircularProgressIndicator(color: _detailPurple),
        );
      case DataProviderState.error:
        if (isUnauthorizedError(state.error)) {
          return const Center(
            child: CircularProgressIndicator(color: _detailPurple),
          );
        }
        return _DetailError(
          message: friendlyErrorMessage(
            state.error,
            'Unable to load course details.',
          ),
          onRetry:
              () =>
                  ref
                      .read(
                        CourseJoinDetailViewModel.provider(courseId).notifier,
                      )
                      .fetch(),
        );
      case DataProviderState.data:
        final detail = state.data;
        if (detail == null) {
          return const _DetailError(message: 'No course detail found.');
        }
        return RefreshIndicator(
          color: _detailPurple,
          onRefresh:
              () =>
                  ref
                      .read(
                        CourseJoinDetailViewModel.provider(courseId).notifier,
                      )
                      .fetch(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // ~98% of the viewport width, with the remaining 2% split
              // evenly as left/right spacing (via the Center below) — wider
              // than the previous 95% so the content cards (countdown,
              // description, objectives, skills, course structure) span a
              // larger portion of the screen.
              final maxWidth = constraints.maxWidth * 0.98;
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                // The hero (#page-heading) and the launch band
                // (#launches-haad) are full-width strips on the web —
                // their purple/#EEEFF9 backgrounds span the whole viewport
                // while only their inner content is centered. The cards
                // below stay centered at 95% width.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CourseHero(
                      detail: detail,
                      onTapReviews:
                          () => showReviewsModal(
                            context,
                            ref,
                            courseId: detail.id,
                          ),
                    ),
                    Transform.translate(
                      // Web `#launches-haad` pulls the launch card up
                      // over the hero with `margin-top: -20px`
                      // (desktop) / `-16px` (mobile).
                      offset: Offset(
                        0,
                        MediaQuery.sizeOf(context).width < 768 ? -16 : -20,
                      ),
                      child: _LaunchPanel(
                        detail: detail,
                        fullBleed: true,
                      ),
                    ),
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // CSS/markup ref, confirmed against `origin/staging`'s
                            // joinCourse.php: `#participang-area .content-heading-
                            // title` is a white card (padding 16px 24px) holding
                            // ("Download Participant Guide") and/or ("WRAP
                            // Methodology") pill links (bg `--purple-tint-bg`
                            // #F5F3FF, border rgba(92,82,212,.08), radius 10,
                            // 14px/600, hover filled #693D94/white) with a 1×24px
                            // #E5E7EB divider between them when both exist. Shown
                            // whenever a URL is present (not gated on enrollment,
                            // mirroring the web), and downloaded through
                            // DownloadButton (encrypted, in-app-only, never a raw
                            // external link).
                            if (detail.participantGuide != null ||
                                detail.wrapMethodology != null)
                              _ParticipantGuideCard(detail: detail),
                            if (constraints.maxWidth >= 760)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _DescriptionCard(detail: detail),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _CourseImageCard(url: detail.logo),
                                  ),
                                ],
                              )
                            else ...[
                              _DescriptionCard(detail: detail),
                              _CourseImageCard(url: detail.logo),
                            ],
                            _SkillsCard(skills: detail.skills),
                            _StructureCard(
                              courseId: detail.id,
                              items: detail.structures,
                              isEnrolled: detail.isEnrolled,
                              courseTitle: detail.title,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const AppFooter(),
                  ],
                ),
              );
            },
          ),
        );
    }
  }
}

void _goBackToCatalog(BuildContext context, WidgetRef ref) {
  // Belt-and-suspenders: if the catalog already has a search/skill/behavior
  // filter applied, re-fetch it now rather than trusting whatever is
  // already cached in CourseCatalogViewModel.provider - it's a kept-alive
  // provider (see course_catalog_view_model.dart) so this is normally a
  // no-op, but guarantees the filtered results are what's shown instead of
  // whatever got left behind if something else invalidated it while this
  // detail page was open.
  final catalog = ref.read(CourseCatalogViewModel.provider);
  final hasFilter =
      catalog.search.isNotEmpty ||
      catalog.skillId != null ||
      catalog.behaviorId != null;
  if (hasFilter) {
    ref.read(CourseCatalogViewModel.provider.notifier).fetch();
  }
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  Modular.to.navigate(CoursesModule.construct(CoursesModule.root));
}

class _CourseHero extends StatelessWidget {
  const _CourseHero({required this.detail, required this.onTapReviews});
  final CourseJoinDetail detail;
  final VoidCallback onTapReviews;

  @override
  Widget build(BuildContext context) {
    // CSS ref: `#page-heading` — desktop (max-width 768) padding
    // `48px 0 44px`; mobile (`@media max-width:767px`) `32px 0 24px`.
    // The 44/24 bottom padding is what forms the purple gap above the
    // launch panel once that card is pulled up by its negative translate
    // (44 − 20 = 24px on desktop, 24 − 16 = 8px on mobile, matching the
    // web exactly). `#page-heading::after`'s notch rule has `content`
    // commented out (and app.css has no such rule), so no notch strip
    // is drawn on the web and none is added here.
    //
    // The whole strip is full-bleed purple (#page-heading spans the full
    // viewport on the web); only its inner content is centered at 95%.
    final phone = MediaQuery.sizeOf(context).width < 768;
    return Container(
      color: _detailPurple,
      padding: EdgeInsets.fromLTRB(0, 10, 0, phone ? 24 : 44),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.95,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 34, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CSS ref, confirmed against `origin/staging`'s joinCourse.php:
                // #page-heading h2 — 32px/weight700 (was 24px/800), letter-
                // spacing -0.5px (was none); mobile shrinks to 24px.
                Text(
                  detail.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: phone ? 24 : 32,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                    letterSpacing: -0.5,
                  ),
                ),
                // #page-heading h2 has `margin: 0 0 12px 0`.
                const SizedBox(height: 12),
                // CSS/markup ref, confirmed against `origin/staging`'s
                // _rating_summary.php: `.average-rating-section` — inline-flex
                // row, gap 12px, containing (in order): star rating, numeric
                // average, and (if `display_rating`) a review-count pill, then
                // (if `allow_rating`) the "Add Rating" pill — both pills share
                // `#page-heading .course-rating-summary a`'s styling (bg
                // white@.15, border white@.25, radius 30, padding 4px 12px).
                // `CourseJoinDetail.displayRating`/`averageRating`/
                // `ratingCount` now parsed from `actionJoinCourseDetail`'s
                // payload, which already dumps the whole Course model
                // (including these columns) — was previously left unparsed and
                // flagged as a backend gap that, on closer look, isn't one.
                // .average-rating-section is inline-flex gap 10px; the two
                // review/Add-Rating pills each carry `margin: 0 0 0 6px`, so the
                // pill gaps become 16px (10 + 6) — hence Wrap spacing 16.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (detail.displayRating) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HeroStars(rating: detail.averageRating),
                          const SizedBox(width: 10),
                          Text(
                            '${detail.averageRating.toStringAsFixed(1)}/5',
                            style: GoogleFonts.inter(
                              // rgba(255,255,255,.95)
                              color: Color(0xF2FFFFFF),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      _HeroPill(
                        onTap: onTapReviews,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '${detail.ratingCount} '),
                              TextSpan(
                                text:
                                    detail.ratingCount == 1
                                    ? 'review'
                                    : 'reviews',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (detail.allowRating)
                      const _HeroPill(child: Text('Add Rating')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroStars extends StatelessWidget {
  const _HeroStars({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    // CSS ref: .rating-stars { color: #ffa534; font-size: 16px; }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        if (i < rating.floor()) {
          icon = Icons.star_rounded;
        } else if (i < rating) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(icon, color: const Color(0xFFFFA534), size: 16);
      }),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .15),
            border: Border.all(color: Colors.white.withValues(alpha: .25)),
            borderRadius: BorderRadius.circular(30),
          ),
          child: DefaultTextStyle(
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _LaunchPanel extends ConsumerStatefulWidget {
  const _LaunchPanel({required this.detail, this.fullBleed = false});
  final CourseJoinDetail detail;

  /// When true, the surrounding #EEEFF9 band (desktop) is a full-bleed
  /// strip spanning the whole viewport with the card centered inside —
  /// matching `#launches-haad` on the web — instead of hugging the page's
  /// centered content column.
  final bool fullBleed;

  @override
  ConsumerState<_LaunchPanel> createState() => _LaunchPanelState();
}

class _LaunchPanelState extends ConsumerState<_LaunchPanel> {
  Timer? _timer;
  bool _enrolling = false;
  bool _cancelling = false;

  Future<void> _enroll() async {
    // Only show the session-picker dialog for classes that have actual
    // upcoming (not-yet-ended) sessions. If all sessions are past, skip
    // the dialog and enroll directly — classLearningEventSelections
    // auto-selects the latest past session as a fallback.
    final classes = widget.detail.classesWithUpcomingSessions;
    if (classes.isNotEmpty) {
      await showDialog(
        context: context,
        builder:
            (_) => _MultiClassRegisterDialog(
              courseTitle: widget.detail.title,
              classes: classes,
              onConfirm: _doEnroll,
            ),
      );
    } else {
      await _doEnroll(widget.detail.classLearningEventSelections);
    }
  }

  Future<void> _doEnroll([Map<int, int>? classLearningEvents]) async {
    setState(() => _enrolling = true);
    final result = await ref
        .read(CourseJoinDetailViewModel.provider(widget.detail.id).notifier)
        .enroll(classLearningEvents: classLearningEvents);
    if (!mounted) return;
    setState(() => _enrolling = false);
    if (result.success) {
      Toast.success(context, result.message ?? 'Enrolled successfully.');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Unable to enroll in this course.'),
        ),
      );
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    final result =
        await ref
            .read(CourseJoinDetailViewModel.provider(widget.detail.id).notifier)
            .cancelRegistration();
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (result.success) {
      Toast.success(
        context,
        result.message ?? 'Registration cancelled successfully.',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Unable to cancel registration.'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Start ticking whenever there's a date to count down to, regardless of
    // enrollment status at mount time - this widget instance is reused (not
    // remounted) when the user enrolls from this same screen, so gating on
    // `isEnrolled` here would freeze the timer forever if it wasn't already
    // true on first build. Visibility of the countdown itself is separately
    // gated by `isEnrolled` in build().
    if (widget.detail.launchDate != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final launchDate = detail.launchDate;
    // Left signed rather than clamped to zero once the target time passes -
    // the session is still open (this is only ever sourced from a still-open,
    // start-through-end session; see nextVirtualClassEvent), so time elapsed
    // since it started is meaningful to show, not just a flat 00:00:00:00.
    Duration? remaining;
    if (launchDate != null) {
      remaining = launchDate.difference(DateTime.now());
    }
    final isPast = (remaining?.isNegative ?? false);
    final remainingAbs = remaining?.abs();
    final phone = MediaQuery.sizeOf(context).width < 768;

    final hasCountdown = launchDate != null && detail.isEnrolled;
    // CSS ref: `#launches-haad .flex-item-1 h6` — 13px/weight700/
    // uppercase/color var(--text-secondary) #6B7280/letter-spacing 0.5px.
    final countLabel = Text(
      isPast ? 'STARTED' : 'LAUNCHES IN',
      style: GoogleFonts.inter(
        color: Color(0xFF6B7280),
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: .5,
      ),
    );
    final timeBoxes = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isPast)
          Padding(
            padding: EdgeInsets.only(right: 2),
            child: Text(
              '-',
              style: GoogleFonts.inter(
                color: _detailInk,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        _timeEntry(remainingAbs?.inDays ?? 0, 'DAYS'),
        _timeEntry((remainingAbs?.inHours ?? 0) % 24, 'HRS'),
        _timeEntry((remainingAbs?.inMinutes ?? 0) % 60, 'MIN'),
        _timeEntry((remainingAbs?.inSeconds ?? 0) % 60, 'SEC'),
      ],
    );
    // Desktop (`flex-item-1`): the h6 label and the .timer sit on the SAME
    // line (`display:flex; align-items:center; gap:16px`), vertically
    // centered. Phone (`@media max-width:767px`) stacks them instead with
    // the label centered above the boxes.
    final countdown = phone
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: countLabel),
              const SizedBox(height: 14),
              timeBoxes,
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              countLabel,
              const SizedBox(width: 16),
              timeBoxes,
            ],
          );

    // CSS ref: `#launches-haad`. Desktop keeps the base app.css band
    // (background #EEEFF9, padding 10px) and pulls the card up with
    // margin-top -20px; mobile (`@media max-width:767px`) drops the band
    // (transparent/0) and uses margin-top -16px. The _CourseHero's bottom
    // padding above accounts for the resulting purple gap (desktop
    // 44−20=24, mobile 24−16=8).
    //
    // With fullBleed the band itself is a full-viewport-width strip
    // (#launches-haad on the web) and the card is centered inside it.
    final card = _InfoCard(
      margin: EdgeInsets.zero,
      // .launches-box: desktop `padding: 20px 24px`; mobile 16px.
      padding: phone
          ? const EdgeInsets.all(16)
          : const EdgeInsets.fromLTRB(24, 20, 24, 20),
      boxShadow: phone
          // mobile `.launches-box` shadow is the stronger indigo one.
          ? const [
            BoxShadow(
              color: Color(0x265C52D4),
              blurRadius: 30,
              offset: Offset(0, 8),
            ),
          ]
          : null,
      child: Column(
        children: [
          // Only show the countdown once the learner is actually enrolled -
          // showing a countdown toward a session they haven't registered
          // for is misleading. On wide screens it sits inline with the
          // primary action button, matching the reference's single header
          // bar instead of stacking them.
          LayoutBuilder(
            builder: (context, constraints) {
              final statusBadge = _statusBadge(detail);
              if (constraints.maxWidth < 768) {
                // `@media max-width:767px` stacks the flex items into a
                // column (`.flex-item-1` full-width/centered so the
                // countdown centers, `.flex-item-4` full-width so the
                // button stretches) with 16px box gap.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasCountdown) ...[
                      Center(child: countdown),
                      const SizedBox(height: 16),
                    ],
                    // #launches-haad .flex-item-4 — mobile centers the
                    // status pill horizontally.
                    Center(child: statusBadge),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: _actionButton(),
                    ),
                  ],
                );
              }
              // Desktop: launches-box is `display:flex; justify-content:
              // space-between` — countdown (label + time boxes on one line)
              // left, the Open/Close status pill centered, action button
              // right. The Expanded keeps the card stretched to the full
              // card width.
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (hasCountdown) countdown,
                  Expanded(child: Center(child: statusBadge)),
                  _actionButton(),
                ],
              );
            },
          ),
          if (detail.learningPath != null) ...[
            SizedBox(height: phone ? 16 : 24),
            // CSS ref: `.learning-path`. Desktop is an UNBOXED sibling
            // in the launches flex row — `h3` 14px/600/text-dark plus a
            // light-blue pill (`span`, bg #E0F2FE / color #0369A1, pad
            // 4px 12px, radius 20, 12px/600, margin-left 6px). The
            // `@media max-width:767px` override boxes it instead: bg
            // --purple-tint-bg (#F5F3FF), padding 12px uniform, radius
            // 10, width 100%, centered, h3 shrinks to 13px, pill margin
            // becomes 4px top/0 left.
            if (phone)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Learning Path: ',
                      style: GoogleFonts.inter(
                        color: _detailInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        detail.learningPath!,
                        style: GoogleFonts.inter(
                          color: Color(0xFF0369A1),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Learning Path: ',
                    style: GoogleFonts.inter(
                      color: _detailInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      detail.learningPath!,
                      style: GoogleFonts.inter(
                        color: Color(0xFF0369A1),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );

    final band = Container(
      // Web: `#launches-haad { margin-bottom: 20px }`; the negative top
      // pull-up lives on _DetailBody's Transform.translate.
      margin: const EdgeInsets.only(bottom: 20),
      padding: phone ? EdgeInsets.zero : const EdgeInsets.all(10),
      decoration: phone
          ? null
          : const BoxDecoration(color: Color(0xFFEEEFF9)),
      child: card,
    );

    if (!widget.fullBleed) return band;
    // Full-bleed: the grey band (#EEEFF9) spans the whole viewport width;
    // only the card inside is centered. Desktop keeps the original width
    // (~98% of the viewport); mobile reduces it to a narrower centered
    // card instead of stretching full-width.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardMaxWidth = phone
        // Single column of launches content is far narrower than the screen
        // (countdown + pill + a full-width action button), so cap the card
        // at a fixed centered width rather than letting it span the whole
        // viewport.
        ? 520.0
        : screenWidth * 0.98;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: phone
          ? null
          : const BoxDecoration(color: Color(0xFFEEEFF9)),
      padding: phone
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(vertical: 10),
      width: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: cardMaxWidth),
          child: card,
        ),
      ),
    );
  }

  /// Status pill: a full ring when the course is closed (nothing left to
  /// complete), or the learner's actual completion percentage when it's
  /// still open.
  Widget _statusBadge(CourseJoinDetail detail) {
    final isClosed = detail.launchStatus.toLowerCase().contains('closed');
    final progress = isClosed ? 1.0 : detail.progressPercentage;
    // CSS ref: #launches-haad .booked — bg #F5F3FF (was #F6F3FF), border
    // 1px rgba(92,82,212,.08) — a distinct indigo (was the generic
    // cardBorders token, then briefly this app's purple in an earlier
    // fix — `rgb(92,82,212)` is `#5C52D4`, not `--primary-first`
    // `#693D94`), padding 8px 16px. .booked h3 — 13px/weight700/
    // uppercase/letter-spacing .5px (was unspecified size, weight 800,
    // no letter-spacing). .pie_progress — 32x32 (was 36x36).
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        border: Border.all(
          color: const Color(0xFF5C52D4).withValues(alpha: 0.08),
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            detail.launchStatus.toUpperCase(),
            style: GoogleFonts.inter(
              color: _detailPurple,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  color: _detailPurple,
                  backgroundColor: Colors.white,
                ),
                Text(
                  '${(progress * 100).round()}%',
                  // CSS ref: `.pie_progress__content` — 10px/weight700.
                  style: GoogleFonts.inter(
                    color: _detailPurple,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton() {
    final detail = widget.detail;
    // CSS ref: #launches-haad .primary-btn — padding 12px 28px (was 20
    // horizontal only), radius 12 (was 10), 14px/weight600 (was 800),
    // shadow 0 4px 14px var(--purple-shadow) i.e. rgba(92,82,212,.2) —
    // was no shadow at all (elevation 0); hover shadow 0 6px 20px
    // rgba(92,82,212,.35). Mobile (`@media max-width:767px`): width 100%,
    // padding 10px 20px. Wrapped in a Container to get the exact CSS
    // shadow shape/color, since Material's elevation model can't
    // reproduce it via ElevatedButton's own shadowColor/elevation.
    final phone = MediaQuery.sizeOf(context).width < 768;
    return HoverBuilder(
      builder:
          (context, hovering) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF5C52D4,
                  ).withValues(alpha: hovering ? 0.35 : 0.2),
                  blurRadius: hovering ? 20 : 14,
                  offset: Offset(0, hovering ? 6 : 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed:
                  (_enrolling || _cancelling)
                      ? null
                      : () {
                        if (detail.isEnrolled) {
                          _showCancelConfirmationDialog(
                            context,
                            onConfirm: _cancel,
                          );
                        } else {
                          _enroll();
                        }
                      },
              icon:
                  (_enrolling || _cancelling)
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.app_registration_rounded, size: 18),
              label: Text(
                _enrolling
                    ? 'Enrolling…'
                    : _cancelling
                    ? 'Cancelling…'
                    : detail.primaryAction,
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 47),
                padding: EdgeInsets.symmetric(
                  horizontal: phone ? 20 : 28,
                  vertical: phone ? 10 : 12,
                ),
                backgroundColor:
                    hovering ? FigmaTokens.purpleHover : _detailPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                textStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
    );
  }

  Widget _timeEntry(int value, String label) {
    // Phone: 4 boxes at 5px padding each overflowed the countdown row by
    // 6.1px on a narrow screen; tighten the gap there.
    final hPad = Responsive.isTablet(context) ? 5.0 : 3.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: _TimeBox(value: value, label: label),
    );
  }
}

class _ParticipantGuideCard extends StatelessWidget {
  const _ParticipantGuideCard({required this.detail});
  final CourseJoinDetail detail;

  @override
  Widget build(BuildContext context) {
    final hasParticipant = detail.participantGuide != null;
    final hasWrap = detail.wrapMethodology != null;
    // CSS ref: `.content-heading-title` — a `--card-bg` card of its own
    // (padding 16px 24px, radius 16, border #F3F4F6, shadow) holding the
    // pill links with a 16px flex gap and a 1×24px #E5E7EB divider between
    // them when BOTH exist. #participang-area has margin-bottom 20px.
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (hasParticipant)
            DownloadButton(
              url: detail.participantGuide,
              label: 'Participant Guide',
              guideLabel: 'Download Participant Guide',
              icon: Icons.picture_as_pdf_rounded,
              guidePill: true,
              courseClass: null,
              builder: (ctx, file) => PdfContentViewer(file: file),
            ),
          if (hasParticipant && hasWrap) const _PillDivider(),
          if (hasWrap)
            DownloadButton(
              url: detail.wrapMethodology,
              label: 'WRAP Methodology',
              guideLabel: 'WRAP Methodology',
              icon: Icons.picture_as_pdf_rounded,
              guidePill: true,
              courseClass: null,
              builder: (ctx, file) => PdfContentViewer(file: file),
            ),
        ],
      ),
    );
  }
}

/// 1×24px divider between the participant-guide/WRAP pills, matching
/// `#participang-area .content-heading-title span` (width 1px, height 24px,
/// background var(--border-medium) #E5E7EB).
class _PillDivider extends StatelessWidget {
  const _PillDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      height: 24,
      child: ColoredBox(color: Color(0xFFE5E7EB)),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.detail});
  final CourseJoinDetail detail;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CSS ref: .content-text h1 margin-bottom 14 (was 28); .content-
          // text p — 15px/lh1.7/#6B7280 (was 16/1.55/noteBodyText's
          // #6A7282, one hex digit off).
          const _SectionTitle('Course Description'),
          if (detail.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              detail.description,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Color(0xFF6B7280),
                height: 1.7,
                fontSize: 15,
              ),
            ),
          ],
          // CSS ref: .content-text h1:not(:first-child) — margin-top 24,
          // padding-top 20, border-top 1px solid var(--border-light)
          // (#F3F4F6).
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFF3F4F6)),
          const SizedBox(height: 20),
          const _SectionTitle('Learning Objectives'),
          if (detail.objective.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              detail.objective,
              style: GoogleFonts.inter(
                color: Color(0xFF6B7280),
                height: 1.7,
                fontSize: 15,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CourseImageCard extends StatelessWidget {
  const _CourseImageCard({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    // CSS ref: .emotional-leadership — the card's own 16px padding
    // applies here too (unlike before, which zeroed it out to run the
    // image edge-to-edge); the image itself gets its own 12px radius
    // (distinct from the card's 16px) and a 220px height (was a flat
    // 380px — reduced per request for the default/catalog image).
    return _InfoCard(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: double.infinity,
          height: 220,
          child:
              url == null
                  ? const CourseImageFallback()
                  : Image.network(
                    url!,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const CourseImageFallback(),
                  ),
        ),
      ),
    );
  }
}

class _SkillsCard extends StatelessWidget {
  const _SkillsCard({required this.skills});
  final List<String> skills;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      margin: const EdgeInsets.fromLTRB(12, 34, 12, 78),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Skills or Behaviors'),
          // CSS ref: #skills-behavior .skills h2 { margin-bottom: 16px }.
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 16),
            // CSS ref: .skills-list li — bg var(--purple-tint-bg) #F5F3FF
            // (was #F6F3FF, one hex digit off), border 1px rgba(92,82,
            // 212,.08) (was the generic cardBorders token), radius 20
            // (was 22). .skills-list li a — padding 6px 16px (was
            // 12/18), 13px/weight600 (was default size).
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  skills
                      .map(
                        (skill) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            // rgba(92,82,212,.08) — the same distinct
                            // indigo (#5C52D4), not this app's purple.
                            border: Border.all(
                              color: const Color(
                                0xFF5C52D4,
                              ).withValues(alpha: 0.08),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            skill,
                            style: GoogleFonts.inter(
                              color: _detailPurple,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StructureCard extends StatelessWidget {
  const _StructureCard({
    required this.courseId,
    required this.items,
    required this.isEnrolled,
    required this.courseTitle,
  });
  final int courseId;
  final List<CourseStructureItem> items;
  final bool isEnrolled;
  final String courseTitle;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 88),
      padding:
          items.isEmpty
              ? const EdgeInsets.all(22)
              : const EdgeInsets.fromLTRB(22, 22, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CSS ref: .structure-block h1 — 22px, margin-bottom 24px
          // (was 20px sized, 28px gap).
          const _SectionTitle('Course Structure', large: true),
          const SizedBox(height: 24),
          if (items.isEmpty)
            Text(
              'No course structure is available.',
              style: GoogleFonts.inter(color: _detailMuted),
            )
          else
            _buildRows(context),
        ],
      ),
    );
  }

  /// Small screens mirror the web's `@media (max-width: 767px)` UI: the
  /// table thead is hidden (#course-class-report table thead display:none),
  /// each `tr` becomes a stacked card (white, border #F3F4F6, radius 16,
  /// padding 16, bottom margin 20, shadow 0 4px 12px rgba(0,0,0,.03)),
  /// the # number cell is dropped (td:first-child display:none), and each
  /// remaining cell renders as a full-width label:value row. There is no
  /// horizontal scrolling on small screens — that is a desktop-only
  /// overflow affordance.
  Widget _buildRows(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 768;
    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _StructureItemCard(
                index: i + 1,
                courseId: courseId,
                item: items[i],
                isEnrolled: isEnrolled,
                courseTitle: courseTitle,
                phone: true,
              ),
            ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Full available width - only falls back to a fixed 900px
        // (with horizontal scroll) when the card is narrower than
        // that, e.g. on small screens.
        final tableWidth = constraints.maxWidth;
        final needsScroll = tableWidth < 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (needsScroll)
              Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swipe_rounded,
                      size: 14,
                      color: _detailMuted,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Swipe to see Next Session, Status & Actions',
                      style: GoogleFonts.inter(
                        color: _detailMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            _StructureTableScroller(
              width: tableWidth < 900 ? 900 : tableWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _StructureHeaderRow(),
                  const SizedBox(height: 8),
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StructureItemCard(
                        index: i + 1,
                        courseId: courseId,
                        item: items[i],
                        isEnrolled: isEnrolled,
                        courseTitle: courseTitle,
                        phone: false,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Wraps the Course Structure table in a horizontally-scrolling area with
/// an always-visible scrollbar - on a narrow screen the table needs a
/// swipe to reveal Next Session/Status/Action, and without a visible
/// scrollbar that content just looked cut off with no indication more
/// was there.
class _StructureTableScroller extends StatefulWidget {
  const _StructureTableScroller({required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  State<_StructureTableScroller> createState() =>
      _StructureTableScrollerState();
}

class _StructureTableScrollerState extends State<_StructureTableScroller> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(width: widget.width, child: widget.child),
      ),
    );
  }
}

class _StructureHeaderRow extends StatelessWidget {
  const _StructureHeaderRow();

  @override
  Widget build(BuildContext context) {
    // CSS ref: #course-class-report table thead th — bg #F8FAFC (was an
    // invented purple tint #EDEAF6), color #475569 (was the muted
    // token), 12px/weight600/letter-spacing 0.5px (was 11px/800/0.3),
    // padding 16px 20px (was 16/12/16/12).
    final style = GoogleFonts.inter(
      color: Color(0xFF475569),
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: .5,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 28, child: Text('#', style: style)),
          SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.only(right: 24),
              child: Text('COURSE DETAILS', style: style),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.only(right: 24),
              child: Text('NEXT SESSION', style: style),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: EdgeInsets.only(right: 24),
              child: Text('STATUS', style: style),
            ),
          ),
          Expanded(flex: 6, child: Text('ACTION', style: style)),
        ],
      ),
    );
  }
}

class _StructureItemCard extends ConsumerStatefulWidget {
  const _StructureItemCard({
    required this.index,
    required this.courseId,
    required this.item,
    required this.isEnrolled,
    required this.courseTitle,
    this.phone = false,
  });
  final int index;
  final int courseId;
  final CourseStructureItem item;
  final bool isEnrolled;
  final String courseTitle;
  final bool phone;

  @override
  ConsumerState<_StructureItemCard> createState() => _StructureItemCardState();
}

class _StructureItemCardState extends ConsumerState<_StructureItemCard> {
  bool _cancelling = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Ticks so "Next Session" and the per-class Register action re-evaluate
    // against the current time without needing a manual refresh - a session
    // that ends while this screen is open should disappear/disable itself
    // live, not just the next time the API is refetched.
    if (widget.item.learningEvents.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cancelClass() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    final result = await ref
        .read(CourseJoinDetailViewModel.provider(widget.courseId).notifier)
        .cancelRegistration(classId: widget.item.classId);
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (result.success) {
      Toast.success(
        context,
        result.message ?? 'Registration cancelled successfully.',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Unable to cancel registration.'),
        ),
      );
    }
  }

  /// Confirms the date/time (matching the website's Register -> Confirm
  /// flow), then registers just this one class/session via
  /// POST lms-screen/register-course in its single-class mode
  /// (class_id + learning_event_class_id) - not the whole-course enroll.
  /// Used by both Virtual Class (typeCode '3') and In Person (typeCode '2')
  /// items - both carry the same learningEvents/session structure.
  Future<void> _registerForSession() async {
    final classId = widget.item.classId;
    if (classId == null) return;
    final event = _earliestUpcomingEvent(widget.item.learningEvents);
    if (event == null) {
      // Every session this class has is already over - registering with no
      // session id just gets rejected by the API ("A session must be
      // selected for this class"), which reads like a bug rather than the
      // simple fact that there's nothing left to register for.
      Toast.error(context, 'No upcoming session is available for this class.');
      return;
    }
    await showDialog(
      context: context,
      builder:
          (_) => _SessionRegisterDialog(
            courseTitle: widget.courseTitle,
            event: event,
            onConfirm:
                () => _registerClass(classId, event.learningEventClassId),
          ),
    );
  }

  Future<void> _registerClass(int classId, int? learningEventClassId) async {
    final result = await ref
        .read(CourseJoinDetailViewModel.provider(widget.courseId).notifier)
        .registerClass(
          classId: classId,
          learningEventClassId: learningEventClassId,
        );
    if (!mounted) return;
    if (result.success) {
      Toast.success(context, result.message ?? 'Registered successfully.');
    } else {
      Toast.error(context, result.message ?? 'Unable to register.');
    }
  }

  /// Opens the virtual class URL in the in-app WebView, auto-logged in via
  /// redirect-login-link so the learner doesn't see the website login form.
  ///
  /// A class can carry multiple session links (one per learning_event).
  /// Picked fresh at click time - not from a value cached at the last
  /// fetch - so a link that expired while the learner was looking at the
  /// screen doesn't still get sent to redirect-login-link: only a link on
  /// this app's own domain, whose session hasn't ended, and (among those)
  /// the one starting soonest is eligible. If nothing qualifies, this stops
  /// before ever calling redirect-login-link or opening the WebView and
  /// tells the learner why instead.
  Future<void> _attendClass(CourseStructureItem item) async {
    if (!mounted) return;
    final appHost = Uri.parse(ref.read(ServerProvider.serverUrl)).host;
    final event = _selectAttendClassEvent(item.learningEvents, appHost);
    final sessionLink = event?.sessionLink;
    if (sessionLink == null) {
      Toast.error(
        context,
        'No active session link is available for this class right now.',
      );
      return;
    }

    String? loginLink;
    try {
      loginLink = await ref
          .read(RedirectLoginRepository.provider)
          .getLoginLink(sessionLink);
    } catch (e) {
      if (mounted) Toast.error(context, 'Could not get login link: $e');
    }
    if (!mounted) return;
    await InAppWebViewPage.show(
      context,
      url: loginLink ?? sessionLink,
      title: item.title,
    );
  }

  /// Marks this Virtual Class as completed (POST
  /// learning-event/learning-event-completion) when the learner opens its
  /// recording in an external browser - there's no way to track how much
  /// they actually watch there, so open is the only signal available.
  /// Downloading no longer marks it complete on its own; when the
  /// recording is played in the in-app player instead, completion is
  /// driven by actual watch progress (see VideoContentViewer's 30%
  /// threshold) rather than this method.
  void _markRecordingWatched() {
    final classId = widget.item.classId;
    if (classId == null) return;
    ref
        .read(RoasterViewModel.provider(widget.courseId.toString()).notifier)
        .markAsRead(
          CourseClass(
            courseId: widget.courseId.toString(),
            classId: classId.toString(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isEnrolled = widget.isEnrolled;
    final courseTitle = widget.courseTitle;
    // Recomputed against DateTime.now() on every rebuild (see the ticking
    // _timer above) rather than read from item.nextSession, which is a
    // string baked once at the last fetch - that field only advances when
    // the API is refetched, so it kept showing an already-ended session's
    // date/time until the user manually refreshed.
    //
    // "Next Session" specifically means a session that hasn't started yet -
    // once its start time passes it's no longer "next", so this uses a
    // strictly-future selector rather than the still-open-through-end one
    // Register/Attend use below.
    final upcomingEvent =
        item.learningEvents.isNotEmpty
            ? _earliestNotYetStartedEvent(item.learningEvents)
            : null;
    final liveNextSession =
        item.learningEvents.isNotEmpty
            ? (upcomingEvent?.startDateTime != null
                ? _formatFriendlyMoment(upcomingEvent!.startDateTime!)
                : null)
            : (item.nextSession.isNotEmpty ? item.nextSession : null);
    // Registration/attendance stays open for a session's whole duration -
    // from start through end, not just before it starts - matching the
    // website, so this uses the still-open selector rather than
    // upcomingEvent above.
    final liveEvent =
        item.learningEvents.isNotEmpty
            ? _earliestUpcomingEvent(item.learningEvents)
            : null;
    // A class with learning_events but none still open has nothing left to
    // register for - hide the Register action instead of leaving it
    // clickable only to fail with a toast.
    final hasRegisterableSession =
        item.learningEvents.isEmpty || liveEvent != null;
    // Same set of possible actions as before, just collected into a list so
    // they can be laid out as a compact Wrap in the ACTION column instead of
    // a full-width stacked Column.
    final actions = <Widget>[
      // CSS ref: #course-structure .static-list-action-btn .btn-ul
      // a[title="Details"] — the "Outline CTA" variant: bg white, border
      // 1.5px var(--border-medium) #E5E7EB, color var(--text-dark)
      // #111827 (was 32px height/8px radius/ink-token/generic border);
      // hover: border+text purple, bg var(--purple-tint-bg) #F5F3FF.
      // Shares the same padding 8/16, radius 10, 13px/weight600, min-
      // height 38, shadow 0 2px4px rgba(0,0,0,.02) as every action-
      // column button.
      if (item.showDetails)
        HoverBuilder(
          builder:
              (context, hovering) => Container(
                constraints: const BoxConstraints(minHeight: 38),
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x05000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: OutlinedButton.icon(
                  onPressed:
                      () => _showClassDetails(context, courseTitle, item),
                  icon: Icon(
                    Icons.info_rounded,
                    size: 14,
                    color: hovering ? _detailPurple : const Color(0xFF111827),
                  ),
                  label: const Text('Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        hovering ? _detailPurple : const Color(0xFF111827),
                    backgroundColor:
                        hovering ? const Color(0xFFF5F3FF) : Colors.white,
                    side: BorderSide(
                      color: hovering ? _detailPurple : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
        ),
      // Registered Virtual Class or In Person class: Attend Class
      // (Virtual only, via contentUrl) + optional recordings + Cancel
      if ((item.typeCode == '3' || item.typeCode == '2') &&
          item.isEnrolledInClass) ...[
        // Shown for any enrolled Virtual Class regardless of whether a
        // qualifying session link currently exists - the domain/expiry
        // filtering happens at click time in _attendClass, which tells the
        // learner why via a toast when nothing qualifies, instead of the
        // button just silently disappearing.
        if (item.typeCode == '3')
          _OnlineActionButton(
            icon: Icons.send_rounded,
            label: 'Attend Class',
            onPressed: () => _attendClass(item),
          ),
        // Recordings — Watch (browser) or Download (offline) + play in
        // the in-app player. Watching in the browser has no way to
        // track progress, so that still marks the class completed on
        // open; downloading no longer does - completion for the
        // in-app player instead fires once 30% of the video has
        // actually played (see VideoContentViewer).
        for (final recordingUrl in item.recordingUrls) ...[
          _OnlineActionButton(
            icon: Icons.play_circle_outline_rounded,
            label: 'Watch Recording',
            onPressed: () {
              _openUrl(context, ref, recordingUrl, title: 'Watch Recording');
              _markRecordingWatched();
            },
          ),
          DownloadButton(
            url: recordingUrl,
            label: 'Recording',
            icon: Icons.videocam_rounded,
            courseClass: null,
            builder:
                (ctx, file) => VideoContentViewer(
                  file: file,
                  courseId: widget.courseId.toString(),
                  classId: item.classId?.toString(),
                ),
          ),
        ],
        _OnlineActionButton(
          icon: Icons.cancel_outlined,
          label: _cancelling ? 'Cancelling…' : 'Cancel Registration',
          danger: true,
          onPressed:
              () => _showCancelConfirmationDialog(
                context,
                onConfirm: _cancelClass,
              ),
        ),
      ] else if (item.typeCode == '4') ...[
        // Watch Video — the external link (e.g. YouTube, content.
        // watch_video_link) and the actually-uploaded file (content.
        // video_upload_url, handled by the DownloadButton below) are
        // independent - a class can have either, both, or neither.
        if (item.videoLinkUrl != null)
          _OnlineActionButton(
            icon: Icons.play_circle_outline_rounded,
            label: 'Watch Video',
            onPressed:
                () => _openUrl(
                  context,
                  ref,
                  item.videoLinkUrl!,
                  title: item.title,
                ),
          ),
      ] else
      // A Virtual Class or In Person class with no live open session left
      // has nothing to register for anymore - hide Register instead of
      // leaving a dead button (see hasRegisterableSession above).
      if (item.showAction &&
          ((item.typeCode != '3' && item.typeCode != '2') ||
              hasRegisterableSession))
        (item.typeCode == '3' || item.typeCode == '2') && isEnrolled
            ? _OnlineActionButton(
              icon: _actionIcon(item.icon),
              label: item.actionLabel,
              onPressed: _registerForSession,
            )
            : _EnrollActionButton(
              isEnrolled: isEnrolled,
              icon: _actionIcon(item.icon),
              label: item.actionLabel,
              item: item,
            ),
      // downloadUrl is populated straight from the course-structure API
      // response regardless of enrollment, so gate visibility on isEnrolled
      // here too - otherwise non-enrolled learners can see (and use) the
      // Download button for course content.
      if (item.downloadUrl != null && isEnrolled)
        if (item.typeCode == '4')
          DownloadButton(
            url: item.downloadUrl,
            label: _downloadLabel(item.typeCode),
            icon: Icons.videocam_rounded,
            courseClass: null,
            builder:
                (ctx, file) => VideoContentViewer(
                  file: file,
                  courseId: widget.courseId.toString(),
                  classId: item.classId?.toString(),
                ),
          )
        else
          DownloadButton(
            url: item.downloadUrl,
            label: _downloadLabel(item.typeCode),
            icon: Icons.picture_as_pdf_rounded,
            courseClass: null,
            builder: (ctx, file) => PdfContentViewer(file: file),
          ),
      // Certificate (typeCode '12') has no downloadUrl at all - the API
      // gives back the certificate's raw HTML directly instead of a file
      // URL, so this uses `url` purely as a cache key (the actual save
      // uses rawContent, not a network fetch - see DownloadButton).
      if (item.typeCode == '12' && item.certificateHtml != null && isEnrolled)
        DownloadButton(
          url: 'certificate_class_${item.classId}',
          rawContent: () => utf8.encode(item.certificateHtml!),
          label: 'Certificate',
          icon: Icons.workspace_premium_rounded,
          courseClass: null,
          builder: (ctx, file) => CertificateContentViewer(file: file),
        ),
    ];

    // Title cell — CSS ref: #course-class-report td h6.number — 15px/
    // weight600/color var(--text-dark) #111827 (was 14.5/800/ink-token
    // #1E2939). #course-class-report td i — 12px/weight500/color
    // var(--text-muted) #9CA3AF (was 12.5/unspecified-weight/a bespoke
    // #9AA4B5). On the mobile stacked card the title uses the web's
    // mobile weight 700.
    final titleCell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.title,
          style: GoogleFonts.inter(
            color: Color(0xFF111827),
            fontSize: 15,
            fontWeight: widget.phone ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        if (item.subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            item.subtitle,
            style: GoogleFonts.inter(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    // Next Session cell — only show a session date once the learner is
    // actually registered for THIS class.
    final nextSessionCell = Padding(
      padding:
          widget.phone ? EdgeInsets.zero : const EdgeInsets.only(right: 24),
      child:
          (liveNextSession != null && item.isEnrolledInClass)
              ? (upcomingEvent != null
                  ? _CompactLaunchCountdown(target: upcomingEvent.startDateTime!)
                  : Text(
                    liveNextSession,
                    // CSS ref: `#course-class-report td span[id^=timer_
                    // started_]` — 13px/weight600/var(--primary-first)
                    // #693D94.
                    style: GoogleFonts.inter(
                      color: _detailPurple,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ))
              : const SizedBox.shrink(),
    );

    // Status cell
    // Fixed width on desktop (not Expanded(flex: 1)) - that squeezed down
    // to ~68px within the row's 900px minimum width (shared across 4 flex
    // sections), wrapping "Registered"/"Completed" onto two lines. 120px
    // comfortably fits either on one. On the mobile card it's full-width.
    final statusCell = SizedBox(
      width: widget.phone ? null : 120,
      child:
          item.status.isEmpty
              ? const SizedBox.shrink()
              : Align(
                alignment: Alignment.centerLeft,
                child:
                    item.classId != null
                        ? ClassStatusChip(
                          courseClass: CourseClass(
                            courseId: widget.courseId.toString(),
                            classId: item.classId!.toString(),
                          ),
                          fallbackStatus: item.status,
                        )
                        : _StatusChip(status: item.status),
              ),
    );

    final actionsCell =
        actions.isEmpty
            ? const SizedBox.shrink()
            // center, not the default start - Details (an OutlinedButton)
            // and the chip-styled action buttons don't render at quite the
            // same height, so top-aligning them in the Wrap made Details
            // look shifted upward relative to its neighbors.
            : (widget.phone
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    // Mobile stacked cards stack the action buttons
                    // full-width, so give each one breathing room.
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        actions[i],
                      ],
                    ],
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: actions,
                  ));

    // Small screens (≤767px) render each row as its own stacked white card
    // per the web's mobile UI: no # column, title on its own line, then
    // Next Session:/Status: label:value rows separated by dividers, and a
    // full-width stacked action column. Everything else on desktop stays a
    // single table row.
    if (widget.phone) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // CSS ref: `@media (max-width:767px) #course-class-report table
          // tbody tr` — white card, border #F3F4F6, radius 16, shadow
          // 0 4px 12px rgba(0,0,0,.03).
          color: Colors.white,
          border: Border.all(color: const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titleCell,
            // td:nth-of-type(2) — block with a bottom border divider.
            if (liveNextSession != null && item.isEnrolledInClass) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 10),
              // ::before "Next Session:" label + value.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Session:',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF6B7280),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: nextSessionCell),
                ],
              ),
            ],
            if (item.status.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status:',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF6B7280),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: statusCell),
                ],
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 10),
              actionsCell,
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        // CSS ref: `#course-class-report tbody tr` — border 1px solid
        // var(--border-light) #F3F4F6 (was the cardBorders #E5E7EB token).
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${widget.index}',
              // CSS ref: `#course-class-report td:first-child` — color
              // var(--text-muted) #9CA3AF (was the darker #6A7282 muted
              // token).
              style: GoogleFonts.inter(
                color: Color(0xFF9CA3AF),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: titleCell,
            ),
          ),
          Expanded(
            flex: 2,
            child: nextSessionCell,
          ),
          statusCell,
          const SizedBox(width: 16),
          Expanded(flex: 6, child: actionsCell),
        ],
      ),
    );
  }
}

/// A compact pill-shaped action button (for the Course Structure table's
/// ACTION column) that disables itself with a "cloud off" state whenever
/// offline, since [onPressed] always performs a network action (opening a
/// link, launching content, etc.).
class _OnlineActionButton extends ConsumerWidget {
  const _OnlineActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  // CSS ref: #course-structure .static-list-action-btn .btn-ul
  // a[title="Cancel"]/.cancelBtn — a distinct "Danger CTA" variant (bg
  // #FEF2F2, border 1px #FEE2E2, color #DC2626; hover bg #FEE2E2) used
  // only for Cancel Registration — was rendering identically to every
  // other action (the purple primary CTA).
  final bool danger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = _watchIsOnline(ref);
    // CSS ref: #course-structure .static-list-action-btn .btn-ul a/button
    // — padding 8px 16px (was 12 horizontal only), radius 10 (was 8),
    // 13px/weight600 (was 12.5/700), min-height 38 (was 32), shadow
    // 0 2px 4px rgba(0,0,0,.02) (was none).
    return HoverBuilder(
      builder:
          (context, hovering) => Container(
            constraints: const BoxConstraints(minHeight: 38),
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child:
                danger
                    ? OutlinedButton.icon(
                      onPressed: isOnline ? onPressed : null,
                      icon: Icon(
                        isOnline ? icon : Icons.cloud_off_rounded,
                        size: 14,
                        color: const Color(0xFFDC2626),
                      ),
                      label: Text(isOnline ? label : 'Internet required'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        backgroundColor:
                            hovering
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFFEF2F2),
                        side: const BorderSide(color: Color(0xFFFEE2E2)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 38),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    )
                    : ElevatedButton.icon(
                      onPressed: isOnline ? onPressed : null,
                      icon: Icon(
                        isOnline ? icon : Icons.cloud_off_rounded,
                        size: 14,
                      ),
                      label: Text(isOnline ? label : 'Internet required'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor:
                            !isOnline
                                ? Colors.grey.shade400
                                : (hovering
                                    ? FigmaTokens.purpleHover
                                    : _detailPurple),
                        disabledBackgroundColor: Colors.grey.shade400,
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 38),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        elevation: 0,
                        textStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
          ),
    );
  }
}

/// The generic course-structure action button (e.g. "Agreement", "Launch
/// Web Application"). Unlike [_OnlineActionButton], the not-enrolled path
/// only opens a local dialog, so it stays enabled offline — only the
/// enrolled/network-performing path gets disabled when offline.
class _EnrollActionButton extends ConsumerWidget {
  const _EnrollActionButton({
    required this.isEnrolled,
    required this.icon,
    required this.label,
    required this.item,
  });
  final bool isEnrolled;
  final IconData icon;
  final String label;
  final CourseStructureItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isEnrolled) {
      // CSS ref: same #course-structure .static-list-action-btn spec as
      // _OnlineActionButton — padding 8/16, radius 10, 13px/weight600,
      // min-height 38, shadow 0 2px 4px rgba(0,0,0,.02).
      return HoverBuilder(
        builder:
            (context, hovering) => Container(
              constraints: const BoxConstraints(minHeight: 38),
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => _showNotEnrolledDialog(context),
                icon: Icon(icon, size: 14),
                label: Text(label),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor:
                      hovering ? FigmaTokens.purpleHover : _detailPurple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  elevation: 0,
                  textStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
      );
    }
    return _OnlineActionButton(
      icon: icon,
      label: label,
      onPressed: () => _handleClassAction(context, ref, item),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(12, 0, 12, 24),
    // CSS ref: .content-text/.skills/#course-structure's card all use
    // padding: 24px (was 22) on desktop; mobile (`@media max-width:767px`)
    // turns the default-padded content cards into 20px + radius 12.
    this.padding,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;

  /// When null, defaults to the responsive value (24px wide / 20px phone).
  /// Callers that must keep a fixed padding (e.g. the 16px image card, the
  /// launch box's own 20×24/16 values) pass it explicitly.
  final EdgeInsetsGeometry? padding;

  /// When null, the shared card shadow (0 1px 3px rgba(0,0,0,.02)) is used.
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    // CSS ref, confirmed against `origin/staging`'s joinCourse.php: every
    // section on this page (launches-box, content-text, skills, course-
    // structure) shares the same `--card-bg`/`--card-radius`/`--card-
    // border`/`--card-shadow` tokens — white, radius 16px (was 12), border
    // 1px solid #F3F4F6 (was missing), shadow 0 1px 3px rgba(0,0,0,.02)
    // (was a much heavier ad-hoc 0 10px 20px @.03). Mobile overrides the
    // content cards to padding 20/radius 12.
    final phone = MediaQuery.sizeOf(context).width < 768;
    final effectivePadding =
        padding ?? (phone ? const EdgeInsets.all(20) : const EdgeInsets.all(24));
    return Container(
      margin: margin,
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(phone ? 12 : 16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow:
            boxShadow ??
            const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.large = false});
  final String text;
  // CSS ref: `.structure-block h1` ("Course Structure") is 22px with a
  // 4×20 accent bar — every other section heading on this page
  // (`.content-text h1`, `#skills-behavior .skills h2`) is 20px/4×18.
  // One shared widget, so the Course Structure caller opts into the
  // larger size explicitly rather than everything being sized the same.
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: large ? 20 : 18,
          decoration: BoxDecoration(
            color: _detailPurple,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: _detailInk,
              fontSize: large ? 22 : 20,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact "LAUNCHES IN" countdown for a single class card - a smaller
/// sibling of _LaunchPanel's course-level countdown, used wherever
/// "Next Session" is shown. Always counts down to a future [target]; the
/// caller only renders this while there's a not-yet-started session to
/// count down to (see upcomingEvent in _StructureItemCardState.build), so
/// unlike the course-level panel this never needs to handle a negative/
/// already-started state - it just gets removed from the tree instead.
/// Compact dash-separated countdown text ("108D - 5H - 30M - 13S") used in
/// the Course Structure table's NEXT SESSION column, instead of
/// [_ClassLaunchCountdown]'s boxed digits.
class _CompactLaunchCountdown extends StatelessWidget {
  const _CompactLaunchCountdown({required this.target});
  final DateTime target;

  @override
  Widget build(BuildContext context) {
    final remaining = target.difference(DateTime.now());
    if (remaining.isNegative) return const SizedBox.shrink();
    final text =
        '${remaining.inDays}D - ${remaining.inHours % 24}H - '
        '${remaining.inMinutes % 60}M - ${remaining.inSeconds % 60}S';
    return Text(
      text,
      // CSS ref: `#course-class-report td span[id^="timer_started_"]` —
      // 13px/weight600/var(--primary-first) #693D94 — the same spec as the
      // plain-text "Next Session" fallback.
      style: GoogleFonts.inter(
        color: _detailPurple,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    // CSS ref: #launches-haad .timer .count — bg #F5F3FF (was #FAF9FF),
    // border 1px rgba(92,82,212,.08) (the same distinct indigo, was the
    // generic cardBorders token), padding 8px 12px (was 14 vertical
    // only), radius 10, shadow 0 2px 6px rgba(92,82,212,.02) (was none).
    // .count span (the number) — 18px/weight700/lh1.1 (was 26px/800 —
    // significantly oversized). .count p (the label) — 10px/weight600/
    // uppercase/color text-secondary #6B7280 (was 9px/800/muted token).
    // Mobile (`@media max-width:767px`): min-width 50, padding 6px 8px,
    // span 15px, label 8px.
    final phone = MediaQuery.sizeOf(context).width < 768;
    return Container(
      width: phone ? 50 : 62,
      padding: EdgeInsets.symmetric(
        horizontal: phone ? 8 : 12,
        vertical: phone ? 6 : 8,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        border: Border.all(
          color: const Color(0xFF5C52D4).withValues(alpha: 0.08),
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5C52D4).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: GoogleFonts.inter(
              color: _detailPurple,
              fontSize: phone ? 15 : 18,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Color(0xFF6B7280),
              fontSize: phone ? 8 : 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _detailMuted, size: 54),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              RetryButton(onRetry: onRetry!, errorMessage: message),
            ],
          ],
        ),
      ),
    );
  }
}

IconData _actionIcon(CourseStructureIcon icon) {
  switch (icon) {
    case CourseStructureIcon.register:
      return Icons.how_to_reg_rounded;
    case CourseStructureIcon.video:
      return Icons.videocam_rounded;
    case CourseStructureIcon.article:
      return Icons.article_rounded;
    case CourseStructureIcon.webpage:
      return Icons.language_rounded;
    case CourseStructureIcon.discussionBoard:
      return Icons.forum_rounded;
    case CourseStructureIcon.tasks:
      return Icons.task_alt_rounded;
    case CourseStructureIcon.coaches:
      return Icons.people_rounded;
    case CourseStructureIcon.insights:
      return Icons.bar_chart_rounded;
    case CourseStructureIcon.certification:
      return Icons.workspace_premium_rounded;
    case CourseStructureIcon.discussionGuru:
      return Icons.chat_rounded;
    case CourseStructureIcon.link:
      return Icons.link_rounded;
    case CourseStructureIcon.agreement:
      return Icons.edit_rounded;
    case CourseStructureIcon.details:
      return Icons.info_rounded;
  }
}

void _handleClassAction(
  BuildContext context,
  WidgetRef ref,
  CourseStructureItem item,
) {
  final url = item.contentUrl;
  switch (item.typeCode) {
    case '4':
      // Watch Video â€” DownloadButton handles this; action button is hidden for type '4'.
      break;
    case '5': // Read Article
    case '15': // Peer Coaching (PDF)
    case '19': // Agreement (PDF)
      if (url == null) return;
      ContentViewPage.show(
        context: context,
        courseClass: null,
        child: PdfContentViewer(file: FileCacheState(url: url)),
      );
      break;
    default:
      if (url != null) _openUrl(context, ref, url, title: item.title);
  }
}

String _downloadLabel(String typeCode) {
  switch (typeCode) {
    case '4':
      return 'Video';
    case '5':
      return 'Article';
    case '15':
      return 'Guide';
    case '19':
      return 'Agreement';
    default:
      return 'File';
  }
}

Future<void> _openUrl(
  BuildContext context,
  WidgetRef ref,
  String url, {
  String? title,
}) async {
  await InAppWebViewPage.showWithAuth(context, ref, url: url, title: title);
}

// ─── Virtual Class session lookup ──────────────────────────────────────────
//
// The course-level "is there an upcoming Virtual Class session" answer
// lives on CourseJoinDetail.nextVirtualClassEvent (single source of truth
// shared with the LAUNCHES IN countdown). This helper is only for picking
// the earliest upcoming event within one specific structure item's own
// learningEvents list.

LearningEvent? _earliestUpcomingEvent(List<LearningEvent> events) {
  final now = DateTime.now();
  LearningEvent? earliest;
  for (final event in events) {
    final start = event.startDateTime;
    if (start == null) continue;
    final end = event.endDateTime;
    // A session stays registerable through its whole duration - from start
    // through end - not just before it starts, matching the website.
    final stillOpen = end == null ? !start.isBefore(now) : now.isBefore(end);
    if (!stillOpen) continue;
    if (earliest == null || start.isBefore(earliest.startDateTime!))
      earliest = event;
  }
  return earliest;
}

/// Picks which session Attend Class should open: among this class's
/// learning events, only those whose training_session_link host matches
/// [appHost] (this app's own configured server domain) are eligible at
/// all - any link pointing somewhere else is ignored outright. Of the
/// remaining candidates, an already-ended one (its end time, or start time
/// if it has no end, has passed) is dropped too - there's no fallback to an
/// expired link. Whatever's left, the one starting soonest wins - whether
/// it's already in progress (started but not yet ended) or hasn't started
/// yet. Returns null when nothing qualifies.
LearningEvent? _selectAttendClassEvent(
  List<LearningEvent> events,
  String appHost,
) {
  final now = DateTime.now();
  LearningEvent? earliest;
  for (final event in events) {
    final link = event.sessionLink;
    if (link == null) continue;
    final uri = Uri.tryParse(link);
    if (uri == null || uri.host.isEmpty) continue;
    if (uri.host.toLowerCase() != appHost.toLowerCase()) continue;

    final start = event.startDateTime;
    if (start == null) continue;
    final end = event.endDateTime;
    final stillOpen = end == null ? !start.isBefore(now) : now.isBefore(end);
    if (!stillOpen) continue;

    if (earliest == null || start.isBefore(earliest.startDateTime!))
      earliest = event;
  }
  return earliest;
}

/// The earliest event that hasn't started yet - unlike [_earliestUpcomingEvent]
/// (which stays "open" through a session's end for Register/Attend), a
/// session already in progress or finished is no longer "next", so it's
/// excluded here even though it may still be registerable/attendable.
LearningEvent? _earliestNotYetStartedEvent(List<LearningEvent> events) {
  final now = DateTime.now();
  LearningEvent? earliest;
  for (final event in events) {
    final start = event.startDateTime;
    if (start == null || !start.isAfter(now)) continue;
    if (earliest == null || start.isBefore(earliest.startDateTime!))
      earliest = event;
  }
  return earliest;
}

// ─── Session Register -> Confirm dialog ────────────────────────────────────
//
// Matches the website's two-step flow: session details + a Register button,
// then a confirm step ("Please confirm the dates and times...") before the
// actual registration call fires.

class _SessionRegisterDialog extends StatefulWidget {
  const _SessionRegisterDialog({
    required this.courseTitle,
    required this.event,
    required this.onConfirm,
  });
  final String courseTitle;
  final LearningEvent event;
  final Future<void> Function() onConfirm;

  @override
  State<_SessionRegisterDialog> createState() => _SessionRegisterDialogState();
}

class _SessionRegisterDialogState extends State<_SessionRegisterDialog> {
  bool _confirming = false;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await widget.onConfirm();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 44),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_detailPurple, _detailPurple2],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    widget.courseTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Positioned(
                    right: -16,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: _confirming ? _buildConfirmStep() : _buildDetailsStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sessionCard(),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          // CSS ref: .btn-modal-primary — radius 10 (was 8), 14px/
          // weight600 (was default/700), hover shadow 0 6px 16px
          // rgba(92,82,212,.3) — the same indigo used throughout this
          // page (was no shadow at all).
          child: HoverBuilder(
            builder:
                (context, hovering) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow:
                        hovering
                            ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF5C52D4,
                                ).withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ]
                            : null,
                  ),
                  child: ElevatedButton(
                    onPressed: () => setState(() => _confirming = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hovering ? FigmaTokens.purpleHover : _detailPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Register',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Please confirm the dates and times for your selections.',
          style: GoogleFonts.inter(color: _detailInk),
        ),
        const SizedBox(height: 6),
        Text(
          'You will receive an email with a calendar invitation for each '
          'learning event after confirmation.',
          style: GoogleFonts.inter(color: _detailMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 16),
        _sessionCard(),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // CSS ref: .btn-modal-secondary — bg #F3F4F6 (was
            // transparent), color #374151 (was ink token), border 1px
            // #E5E7EB (already correct — matches the cardBorders token
            // value exactly), radius 10 (was 8), padding 8px 20px (was
            // 18/12), 14px/weight600 (was default/700).
            OutlinedButton(
              onPressed:
                  _submitting
                      ? null
                      : () => setState(() => _confirming = false),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF3F4F6),
                foregroundColor: const Color(0xFF374151),
                side: const BorderSide(color: FigmaTokens.cardBorders),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
              ),
              child: Text(
                'Previous',
                // CSS ref: .btn-modal-secondary — 14px/weight500 (was 600).
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // CSS ref: .btn-modal-primary — radius 10 (was 8), 14px/
            // weight600 (was default/700), hover shadow 0 6px 16px
            // rgba(92,82,212,.3).
            HoverBuilder(
              builder:
                  (context, hovering) => Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow:
                          hovering
                              ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF5C52D4,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                              : null,
                    ),
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            hovering ? FigmaTokens.purpleHover : _detailPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child:
                          _submitting
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Text(
                                'Confirm',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
            ),
          ],
        ),
      ],
    );
  }

  // CSS ref: real markup wraps this same Start/End/Instructor/Status content
  // in `.event-card` (radius 12, padding 14px 18px), the same class used by
  // the website's radio-select session picker — not `.le-detail-card`
  // (radius 10), which is a visually-similar but unrelated card style used
  // by the read-only Details modal (`_classDetails.php`). This dialog skips
  // the picker step (it always registers for the single earliest upcoming
  // session), so it renders the non-selectable, no-radio variant of
  // `.event-card` — the same shape `confirmationPage()`'s JS builds for the
  // confirm step.
  Widget _sessionCard() => _EventCard(event: widget.event, showLocation: true);
}

// ─── Multi-class Register -> Confirm wizard ────────────────────────────────
//
// Matches the website's step-through flow for whole-course enrollment when
// more than one Virtual/In Person class needs a session picked: one step per
// class (radio-select a session, "Next"), "Register" on the last class's
// step, then a final Confirm step summarizing every selection before the
// actual registration call fires.

class _MultiClassRegisterDialog extends StatefulWidget {
  const _MultiClassRegisterDialog({
    required this.courseTitle,
    required this.classes,
    required this.onConfirm,
  });

  final String courseTitle;
  final List<CourseStructureItem> classes;
  final Future<void> Function(Map<int, int> classLearningEvents) onConfirm;

  @override
  State<_MultiClassRegisterDialog> createState() =>
      _MultiClassRegisterDialogState();
}

class _MultiClassRegisterDialogState extends State<_MultiClassRegisterDialog> {
  late final List<int?> _selectedEventId;
  int _step = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedEventId =
        widget.classes
            .map(
              (item) =>
                  _earliestUpcomingEvent(
                    item.learningEvents,
                  )?.learningEventClassId,
            )
            .toList();
  }

  bool get _isConfirmStep => _step >= widget.classes.length;

  void _toggleSelection(int index, int? eventId) {
    setState(() {
      _selectedEventId[index] =
          _selectedEventId[index] == eventId ? null : eventId;
    });
  }

  List<LearningEvent> _upcomingEventsFor(CourseStructureItem item) {
    final now = DateTime.now();
    // A session stays selectable through its whole duration - from start
    // through end, not just before it starts - matching the website.
    final events =
        item.learningEvents.where((e) {
          final start = e.startDateTime;
          if (start == null) return false;
          final end = e.endDateTime;
          return end == null ? !start.isBefore(now) : now.isBefore(end);
        }).toList();
    events.sort((a, b) => a.startDateTime!.compareTo(b.startDateTime!));
    return events;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final selections = <int, int>{};
    for (var i = 0; i < widget.classes.length; i++) {
      final classId = widget.classes[i].classId;
      final eventId = _selectedEventId[i];
      if (classId != null && eventId != null) selections[classId] = eventId;
    }
    await widget.onConfirm(selections);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 44),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_detailPurple, _detailPurple2],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    widget.courseTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Positioned(
                    right: -16,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child:
                  _isConfirmStep ? _buildConfirmStep() : _buildClassStep(_step),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassStep(int index) {
    final item = widget.classes[index];
    final events = _upcomingEventsFor(item);
    final isLastClass = index == widget.classes.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.title,
          style: GoogleFonts.inter(
            color: _detailInk,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          events.isEmpty
              ? 'Select a session'
              : 'Select a session, or tap it again to skip this class',
          style: GoogleFonts.inter(color: _detailMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          // CSS ref: the placeholder `.event-card` the real JS drops into
          // `#enroll-class-grid-*` when every session is hidden — plain
          // centered 13px/#6B7280 text, no label/value grid.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFF3F4F6)),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              'Currently no classes available!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Color(0xFF6B7280), fontSize: 13),
            ),
          )
        else
          // Always shown as a radio - even with a single session - so the
          // learner explicitly confirms their pick, matching the reference
          // design rather than silently auto-selecting the only option.
          // Tapping the already-selected session deselects it - a class
          // left unselected is simply left out of the registration.
          ...events.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EventCard(
                event: event,
                selectable: true,
                selected: _selectedEventId[index] == event.learningEventClassId,
                showLocation: true,
                onTap:
                    () => _toggleSelection(index, event.learningEventClassId),
              ),
            ),
          ),
        const SizedBox(height: 8),
        // CSS ref: .btn-modal-primary — radius 10 (was 8), 14px/
        // weight600 (was default/700), hover shadow 0 6px 16px
        // rgba(92,82,212,.3).
        SizedBox(
          width: double.infinity,
          child: HoverBuilder(
            builder:
                (context, hovering) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow:
                        hovering
                            ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF5C52D4,
                                ).withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ]
                            : null,
                  ),
                  child: ElevatedButton(
                    onPressed: () => setState(() => _step = index + 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hovering ? FigmaTokens.purpleHover : _detailPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isLastClass ? 'Register' : 'Next',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Please confirm the dates and times for your selections.',
          style: GoogleFonts.inter(color: _detailInk),
        ),
        const SizedBox(height: 6),
        Text(
          'You will receive an email with a calendar invitation for each '
          'learning event after confirmation.',
          style: GoogleFonts.inter(color: _detailMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < widget.classes.length; i++) ...[
          Text(
            widget.classes[i].title,
            style: GoogleFonts.inter(
              color: _detailInk,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _selectedEventId[i] == null
              ? Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: FigmaTokens.cardBorders),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Skipped - this class will not be registered.',
                  style: GoogleFonts.inter(color: _detailMuted),
                ),
              )
              : _EventCard(event: _selectedEventFor(i)!, showLocation: true),
          if (i != widget.classes.length - 1) const SizedBox(height: 16),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // CSS ref: .btn-modal-secondary — bg #F3F4F6, color #374151,
            // border already-correct #E5E7EB, radius 10, padding
            // 8px 20px, 14px/weight600.
            OutlinedButton(
              onPressed:
                  _submitting
                      ? null
                      : () => setState(() => _step = widget.classes.length - 1),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF3F4F6),
                foregroundColor: const Color(0xFF374151),
                side: const BorderSide(color: FigmaTokens.cardBorders),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
              ),
              child: Text(
                'Previous',
                // CSS ref: .btn-modal-secondary — 14px/weight500 (was 600).
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // CSS ref: .btn-modal-primary — radius 10, 14px/weight600,
            // hover shadow 0 6px 16px rgba(92,82,212,.3).
            HoverBuilder(
              builder:
                  (context, hovering) => Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow:
                          hovering
                              ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF5C52D4,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                              : null,
                    ),
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            hovering ? FigmaTokens.purpleHover : _detailPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child:
                          _submitting
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Text(
                                'Confirm',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
            ),
          ],
        ),
      ],
    );
  }

  LearningEvent? _selectedEventFor(int index) {
    final id = _selectedEventId[index];
    if (id == null) return null;
    for (final event in widget.classes[index].learningEvents) {
      if (event.learningEventClassId == id) return event;
    }
    return null;
  }
}

String _formatSessionMoment(DateTime? dt) {
  if (dt == null) return '—';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${months[dt.month - 1]}-${dt.day.toString().padLeft(2, '0')}-${dt.year}\n'
      '$hour12:$minute $ampm';
}

// ─── Event card (radio-select) ─────────────────────────────────────────────
//
// CSS ref: `.event-card`/`.event-card--selectable`/`.event-card-radio`/
// `.event-radio-circle`/`.event-card-body` from `_enroll_partial-class-
// register.php` (the AJAX partial `/course/enroll-class-register` renders
// into `#course_details_modal`) — the real session picker used by whole-
// course enrollment. White bg, border 1px #F3F4F6, radius 12, shadow
// 0 1px 3px rgba(0,0,0,.02); when selectable, hover -> border #693D94 +
// shadow 0 4px 12px rgba(0,0,0,.06). This is a different, unrelated card
// style from `.le-detail-card` (radius 10) used by the read-only Details
// modal - the two look similar but are never the same element in the real
// markup, a mix-up this file made in an earlier pass.
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    this.selectable = false,
    this.selected = false,
    this.onTap,
    this.showLocation = false,
  });

  final LearningEvent event;
  final bool selectable;
  final bool selected;
  final VoidCallback? onTap;
  final bool showLocation;

  @override
  Widget build(BuildContext context) {
    final location = event.location.trim();
    // .event-card-body / (padding 14px 18px inline override for the
    // non-selectable confirm-step card, 10px 14px for the picker step).
    final body = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: selectable ? 14 : 18,
        vertical: selectable ? 10 : 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _dateField('Start', event.startDateTime)),
              Expanded(child: _dateField('End', event.endDateTime)),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              SizedBox(
                width: 130,
                child: _field(
                  'Instructor',
                  event.instructor.isEmpty ? '—' : event.instructor,
                ),
              ),
              SizedBox(width: 130, child: _statusField()),
              if (showLocation && location.isNotEmpty)
                SizedBox(width: 130, child: _field('Location', location)),
            ],
          ),
        ],
      ),
    );

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectable)
          // .event-card-radio — padding 10px 0 10px 12px.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
            child: _EventRadioCircle(selected: selected),
          ),
        Expanded(child: body),
      ],
    );

    return HoverBuilder(
      builder: (context, hovering) {
        final activeHover = selectable && hovering;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: activeHover ? _detailPurple : const Color(0xFFF3F4F6),
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: activeHover ? 0.06 : 0.02,
                ),
                blurRadius: activeHover ? 12 : 3,
                offset: Offset(0, activeHover ? 4 : 1),
              ),
            ],
          ),
          child:
              onTap == null
                  ? content
                  : Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onTap,
                      child: content,
                    ),
                  ),
        );
      },
    );
  }

  // .event-value.event-date + the plain time span right after it — date
  // at 14px/#374151, time at 12px/#9CA3AF underneath.
  Widget _dateField(String label, DateTime? dt) {
    final formatted = _formatSessionMoment(dt).split('\n');
    final date = formatted.first;
    final time = formatted.length > 1 ? formatted[1] : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(label),
        const SizedBox(height: 2),
        Text(
          date,
          style: GoogleFonts.inter(
            color: Color(0xFF374151),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        if (time.isNotEmpty)
          Text(
            time,
            style: GoogleFonts.inter(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
      ],
    );
  }

  Widget _field(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(label),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Color(0xFF374151),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // .event-status-badge / .status-available / .status-waitlist — computed
  // from LearningEventClass::getRegistrationStatus() (available seats =
  // max(0, maxRegistrations - registeredCount)) since the mobile API
  // doesn't send a precomputed status string.
  Widget _statusField() {
    final waitlist = event.isWaitlist;
    final bg = waitlist ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5);
    final fg = waitlist ? const Color(0xFFB45309) : const Color(0xFF059669);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label('Status'),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            waitlist ? 'Waitlist' : 'Available',
            style: GoogleFonts.inter(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // .event-label — 11px/weight600/#9CA3AF/uppercase/letter-spacing .3px
  // (was .5px on the unrelated `.le-detail-card-label`).
  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: GoogleFonts.inter(
      color: Color(0xFF9CA3AF),
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: .3,
    ),
  );
}

// CSS ref: .event-radio-circle — 20x20, border 2px #D1D5DB, radius 50%;
// checked -> border+bg #693D94 with an 8x8 white dot centered inside.
class _EventRadioCircle extends StatelessWidget {
  const _EventRadioCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _detailPurple : Colors.transparent,
        border: Border.all(
          color: selected ? _detailPurple : const Color(0xFFD1D5DB),
          width: 2,
        ),
      ),
      child:
          selected
              ? Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              )
              : null,
    );
  }
}

void _showNotEnrolledDialog(BuildContext context) {
  showDialog(
    context: context,
    builder:
        (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          content: Text(
            'You are not enrolled for this course. Click the Enroll Now button at the top of this page to continue.',
            style: GoogleFonts.inter(color: _detailMuted, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: _detailPurple),
              child: Text(
                'OK',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
  );
}

void _showCancelConfirmationDialog(
  BuildContext context, {
  required VoidCallback onConfirm,
}) {
  // CSS/markup ref, confirmed against `origin/staging`'s joinCourse.php:
  // `#cancel_confirm_modal` — content radius 12 (already correct), shadow
  // 0 10px 25px rgba(0,0,0,.1) (was none); a gradient header (135deg
  // #693D94→#AA399F, white 18px/700 title, padding 16/20) was entirely
  // missing — the title rendered as plain dark text with no header bar at
  // all. Body padding 24, message centered/16px/#333 (was left-aligned/
  // muted-token/no explicit size). "Yes, Cancel" is `.btn-modal-primary`
  // with an inline override to Bootstrap danger red (`#DC3545`, not this
  // app's `#DC2626`) — was solid purple, i.e. visually identical to
  // "confirm" rather than "destroy."
  showDialog(
    context: context,
    builder:
        (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF693D94), Color(0xFFAA399F)],
                  ),
                ),
                child: Stack(
                  children: [
                    Text(
                      'Confirm Cancellation',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Positioned(
                      right: -6,
                      top: -2,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Would you like to cancel your registration for this course?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Color(0xFF333333), fontSize: 16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: FigmaTokens.cardBorders),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        'No, Keep It',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC3545),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        'Yes, Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
  );
}

void _showClassDetails(
  BuildContext context,
  String courseTitle,
  CourseStructureItem item,
) {
  showDialog(
    context: context,
    builder:
        (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          insetPadding: const EdgeInsets.all(20),
          child: _ClassDetailsDialog(courseTitle: courseTitle, item: item),
        ),
  );
}

// CSS ref: `_classDetails.php` never shows the *course's* objective here —
// only the class's own `objective`/`description` (In-Person/Virtual Class
// route through the Schedule partial instead; every other type uses
// `Lmsclass::getAttribDetail()`'s type-specific attribute list, built
// below by `_attributeCards`). The course-level objective this dialog
// used to display here was the wrong data source entirely, not just
// mis-styled - removed rather than kept as an approximation.
class _ClassDetailsDialog extends StatelessWidget {
  const _ClassDetailsDialog({required this.courseTitle, required this.item});

  final String courseTitle;
  final CourseStructureItem item;

  @override
  Widget build(BuildContext context) {
    final typeName =
        item.subtitle.length > 2
            ? item.subtitle.substring(1, item.subtitle.length - 1)
            : '';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 540),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // CSS ref, confirmed against `origin/staging`'s joinCourse.php:
          // `#class_details_modal .modal-header.gradient` — gradient bg
          // 135deg #693D94→#AA399F (was solid purple), padding 16/20
          // (was 20/18/16/18); h3 18px/700 (was 15/800). `.course-type-
          // badge` — bg white@.2 (was .18, and had an extra border not
          // in the real spec), padding 3/10 (was 10/5), 11px/weight600
          // (was 700). Close button is the shared circular "blurred"
          // button (32x32, gradient white→indigo tint, radius 50%,
          // absolute top:12/right:14) — was a bare Icon.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF693D94), Color(0xFFAA399F)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          courseTitle,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (typeName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            typeName,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  right: -6,
                  top: -2,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              // CSS ref: `.class-events-section` — padding 12px 20px 16px
              // (was a flat 20 all round).
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CSS ref: `_classDetails.php` branches on class type —
                  // In-Person/Virtual Class render the Schedule partial
                  // (`_partial-class-detail.php`); every other type renders
                  // `Lmsclass::getAttribDetail()`'s type-specific attribute
                  // list as `.le-detail-card`s instead. This used to always
                  // show Objective/Description/Schedule regardless of type
                  // (bare text, no card chrome), which was correct for
                  // neither branch.
                  if (item.typeCode == '2' || item.typeCode == '3') ...[
                    if (item.description.isNotEmpty) ...[
                      _LeDetailCard(
                        label: 'Description',
                        value: item.description,
                      ),
                    ],
                    if (item.learningEvents.isNotEmpty) ...[
                      if (item.description.isNotEmpty)
                        const SizedBox(height: 12),
                      // CSS ref: `.lc-section-label` — 12px/weight600/
                      // #9CA3AF/uppercase/letter-spacing .8px, margin 12px 0
                      // 8px (was reusing the same 11px/weight800 style as
                      // the card labels above, which is a different class).
                      Padding(
                        padding: EdgeInsets.only(top: 12, bottom: 8),
                        child: Text(
                          'SCHEDULE',
                          style: GoogleFonts.inter(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      // `.event-cards` — column, 10px gaps.
                      for (var i = 0; i < item.learningEvents.length; i++) ...[
                        if (i != 0) const SizedBox(height: 10),
                        _LearningEventCard(event: item.learningEvents[i]),
                      ],
                    ],
                  ] else
                    ..._attributeCards(item),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// CSS ref: `.le-detail-card`/`.le-detail-card-label`/`.le-detail-card-
// value` — white bg, border 1px #F3F4F6, radius 10, padding 12px 16px,
// shadow 0 1px 3px rgba(0,0,0,.02); label 11px/weight600/#9CA3AF/
// uppercase/letter-spacing .5px; value 14px/#374151/lh1.5.
class _LeDetailCard extends StatelessWidget {
  const _LeDetailCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Color(0xFF374151),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// CSS ref: `Lmsclass::getAttribDetail()` — every content-type class other
// than In-Person/Virtual Class (routed to the Schedule branch above) shows
// its own type-specific attribute list here instead, each as a
// `.le-detail-card`. Built from data the mobile API already sends
// (`content.*` fields, already parsed onto [CourseStructureItem] for the
// action buttons elsewhere on this page) rather than the class's own
// `objective`/`instruction` fields, which the API does not send at all —
// see the "Still open" note in the audit doc.
List<Widget> _attributeCards(CourseStructureItem item) {
  final cards = <Widget>[];
  void add(Widget card) {
    if (cards.isNotEmpty) cards.add(const SizedBox(height: 12));
    cards.add(card);
  }

  switch (item.typeCode) {
    case '1': // eLearning
      if (item.description.isNotEmpty) {
        add(_LeDetailCard(label: 'Description', value: item.description));
      }
      break;
    case '4': // Watch Video
      if (item.videoLinkUrl != null) {
        add(
          _LinkDetailCard(
            label: 'Upload Video',
            linkText: 'Video Link',
            url: item.videoLinkUrl!,
          ),
        );
      }
      break;
    case '5': // Read Article
    case '19': // Agreement — same two fields as Read Article
      if (item.articleLinkUrl != null) {
        add(
          _LinkDetailCard(
            label: 'Read Article Link',
            linkText: 'Article link',
            url: item.articleLinkUrl!,
          ),
        );
      }
      if (item.downloadUrl != null) {
        add(
          _LinkDetailCard(
            label: 'Article File',
            linkText: 'Uploaded File',
            url: item.downloadUrl!,
          ),
        );
      }
      break;
    case '6': // Read Webpage
    case '13': // LinkedIn Certification — reuses the webpage link fields
      if (item.contentUrl != null) {
        add(
          _LinkDetailCard(
            label: 'Read Webpage Link',
            linkText:
                item.webpageLinkText?.isNotEmpty == true
                    ? item.webpageLinkText!
                    : 'Open Webpage',
            url: item.contentUrl!,
          ),
        );
      }
      break;
    case '7': // Discussion Board
      if (item.contentUrl != null) {
        add(
          _LinkDetailCard(
            label: 'Discussion Board',
            linkText: 'Discussion Board link',
            url: item.contentUrl!,
          ),
        );
      }
      break;
    case '14': // Discussion Guru
      if (item.contentUrl != null) {
        add(
          _LinkDetailCard(
            label: 'Discussion Guru Link',
            linkText: item.contentUrl!,
            url: item.contentUrl!,
          ),
        );
      }
      break;
    case '15': // Peer Coaching
      if (item.peerCoachingLinkUrl != null) {
        add(
          _LinkDetailCard(
            label: 'Peer Coaching Link',
            linkText: item.peerCoachingLinkUrl!,
            url: item.peerCoachingLinkUrl!,
          ),
        );
      }
      if (item.downloadUrl != null) {
        add(
          _LinkDetailCard(
            label: 'Peer Coaching File',
            linkText: 'Uploaded File',
            url: item.downloadUrl!,
          ),
        );
      }
      break;
    case '17': // OnePage Pro
      if (item.contentUrl != null) {
        add(
          _LinkDetailCard(
            label: 'Read Webpage Link',
            linkText: 'OnePage Pro',
            url: item.contentUrl!,
          ),
        );
      }
      break;
    case '23': // Web App
      if (item.webAppUrl != null) {
        add(
          _LinkDetailCard(
            label: 'One Pager Pro',
            linkText: 'Web Application',
            url: item.webAppUrl!,
          ),
        );
      }
      break;
    // '18' (Custom Prompt), '8'/'9' (Task w/wo Observation), '10' (Receive
    // Coaching), '11' (Insight Report), '12' (Certificate), '20' (Test-Out),
    // '22' (Text Message) all show an empty attribute list in the real
    // `getAttribDetail()` switch - no cards here either.
  }
  return cards;
}

// CSS ref: a `.le-detail-card` whose value is a clickable `<a>` link
// instead of plain text — same card chrome as `_LeDetailCard`, with the
// value styled as a link (primary purple, underlined) and wired to
// url_launcher instead of being inert text.
class _LinkDetailCard extends StatelessWidget {
  const _LinkDetailCard({
    required this.label,
    required this.linkText,
    required this.url,
  });
  final String label;
  final String linkText;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap:
                () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
            child: Text(
              linkText,
              style: GoogleFonts.inter(
                color: _detailPurple,
                fontSize: 14,
                height: 1.5,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// CSS ref: `_partial-class-detail.php`'s Schedule section — `.event-card`
// (white bg, border 1px #F3F4F6, radius 12, shadow 0 1px 3px
// rgba(0,0,0,.02)) with a 4px left `.event-card-badge` gradient accent bar
// (135deg -> here vertical, 180deg #693D94 -> #AA399F) and an
// `.event-card-inner` body (padding 10px 14px) of `.ec-row`/`.ec-block`
// pairs separated by `.ec-divider`s, Start/End joined by a `.ec-arrow`
// "→". This is a third, distinct real card shape from both `.le-detail-
// card` and the radio-select `.event-card` variant in `_EventCard` above
// — same base class, no radio, plus the left accent bar this dialog's
// old plain-bordered box never had.
class _LearningEventCard extends StatelessWidget {
  const _LearningEventCard({required this.event});
  final LearningEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF693D94), Color(0xFFAA399F)],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _EcField.dateTime(
                            label: 'Start',
                            dateTime: event.startDateTime,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: 14),
                          child: Text(
                            '→',
                            style: GoogleFonts.inter(
                              color: Color(0xFFD1D5DB),
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _EcField.dateTime(
                            label: 'End',
                            dateTime: event.endDateTime,
                          ),
                        ),
                      ],
                    ),
                    if (event.instructor.isNotEmpty ||
                        event.location.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (event.instructor.isNotEmpty)
                            Expanded(
                              child: _EcField(
                                label: 'Instructor',
                                value: event.instructor,
                              ),
                            ),
                          if (event.instructor.isNotEmpty &&
                              event.location.isNotEmpty)
                            const SizedBox(width: 8),
                          if (event.location.isNotEmpty)
                            Expanded(
                              child: _EcField(
                                label: 'Location',
                                value: event.location,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (event.instructions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      const SizedBox(height: 6),
                      _EcField(
                        label: 'Instructions',
                        value: event.instructions,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// CSS ref: `.ec-label`/`.ec-value` — same spec as `.event-label`/
// `.event-value` (11px/weight600/#9CA3AF/uppercase/letter-spacing .3px
// label; 14px/#374151/lh1.4 value). Start/End additionally carry a
// `.ec-sub` time line (12px/#9CA3AF) below the date, matching the real
// markup's separate date/time spans.
class _EcField extends StatelessWidget {
  const _EcField({required this.label, required this.value, this.sub});

  // Start/End: splits the shared `Mon-DD-YYYY\nh:mm A` formatter's output
  // into a 14px date value and a 12px/#9CA3AF `.ec-sub` time line, matching
  // the real markup's separate `.ec-value`/`.ec-sub` spans.
  factory _EcField.dateTime({
    required String label,
    required DateTime? dateTime,
  }) {
    final parts = _formatSessionMoment(dateTime).split('\n');
    return _EcField(
      label: label,
      value: parts.first,
      sub: parts.length > 1 ? parts[1] : null,
    );
  }

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: Color(0xFF9CA3AF),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: .3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '—' : value,
          style: GoogleFonts.inter(
            color: Color(0xFF374151),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        if (sub != null && sub!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              sub!,
              style: GoogleFonts.inter(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  // CSS ref, confirmed against `origin/staging`'s joinCourse.php: a full
  // 7-state palette (`.btn-registered`/`.btn-started`/`.btn-complete`/
  // `.btn-passed`/`.btn-waitlist`/`.btn-cancelled`/`.btn-pending`/
  // `.btn-failed`) — was collapsed to just 2 states (green for
  // "completed", one generic purple for everything else), so Registered/
  // Started/Waitlisted/Cancelled/Pending all showed identically.
  static const _states = <String, (Color bg, Color fg)>{
    'registered': (Color(0xFFE0E7FF), Color(0xFF4338CA)),
    'started': (Color(0xFFFEF3C7), Color(0xFFB45309)),
    'complete': (Color(0xFFD1FAE5), Color(0xFF059669)),
    'completed': (Color(0xFFD1FAE5), Color(0xFF059669)),
    'passed': (Color(0xFFD1FAE5), Color(0xFF059669)),
    'waitlist': (Color(0xFFF3E8FF), Color(0xFF7C3AED)),
    'waitlisted': (Color(0xFFF3E8FF), Color(0xFF7C3AED)),
    'cancelled': (Color(0xFFF3F4F6), Color(0xFF6B7280)),
    'canceled': (Color(0xFFF3F4F6), Color(0xFF6B7280)),
    'pending': (Color(0xFFFEF3C7), Color(0xFFB45309)),
    'failed': (Color(0xFFFEE2E2), Color(0xFFDC2626)),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) =
        _states[status.toLowerCase().trim()] ??
        (const Color(0xFFE0E7FF), const Color(0xFF4338CA));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: GoogleFonts.inter(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// "02 Aug 2026 03:40 PM" - used for the "Next Session" line, which (unlike
// `_EcField.dateTime`/`_formatSessionMoment`'s compact two-line schedule-
// card format) needs the full date on one line since it's read out of
// context of a specific card.
//
// Both formatters read the already timezone-corrected DateTime
// (LearningEvent.startDateTime/endDateTime, which convert the API's UTC
// values to local time - see course_join_detail.dart's
// _combineDateAndTime) rather than reparsing the raw date/time strings
// naively. Reparsing them directly used to skip that UTC->local
// conversion, so schedule displays drifted out of sync with the website
// by exactly the device's UTC offset (5:30 on an IST device) even though
// the register/countdown flow elsewhere was correct.
String _formatFriendlyMoment(DateTime dateTime) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = months[dateTime.month - 1];
  final hour = dateTime.hour;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final amPm = hour >= 12 ? 'PM' : 'AM';
  final hour12 = (hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour))
      .toString()
      .padLeft(2, '0');
  return '$day $month ${dateTime.year} $hour12:$minute $amPm';
}

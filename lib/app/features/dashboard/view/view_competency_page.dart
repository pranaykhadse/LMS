import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/model/view_competency.dart';
import 'package:lms/app/features/dashboard/viewmodel/view_competency_view_model.dart';

const _vcPurple = FigmaTokens.primaryPurple;
// CSS ref, confirmed via the browser's own computed-style inspector
// popover on the real `<td class="text-center w0">` (course-name
// cell): `color:#212529; font:14px Inter`. Was `FigmaTokens.cardTitles`
// (`#1E2939`) at 13/13.5px with no font-family — same fix already
// applied to the Learning Paths table's body text.
const _vcInk = Color(0xFF212529);
const _vcMuted = FigmaTokens.noteBodyText;
const _vcBg = FigmaTokens.pageBackground;

class ViewCompetencyPage extends ConsumerWidget {
  const ViewCompetencyPage({
    super.key,
    required this.learningPathId,
    required this.competency,
  });

  final int learningPathId;
  final String competency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ViewCompetencyArgs(
      learningPathId: learningPathId,
      competency: competency,
    );
    final state = ref.watch(ViewCompetencyViewModel.provider(args));

    return AppScaffold(
      backgroundColor: _vcBg,
      title: competency,
      onRefresh:
          () =>
              ref.read(ViewCompetencyViewModel.provider(args).notifier).fetch(),
      body: switch (state.state) {
        DataProviderState.idle || DataProviderState.loading => const Center(
          child: CircularProgressIndicator(color: _vcPurple),
        ),
        DataProviderState.error => _ErrorView(
          message: friendlyErrorMessage(
            state.error,
            'Unable to load competency details.',
          ),
          onRetry:
              () =>
                  ref
                      .read(ViewCompetencyViewModel.provider(args).notifier)
                      .fetch(),
        ),
        DataProviderState.data =>
          state.data == null
              ? const _ErrorView(message: 'No competency details found.')
              : _Body(result: state.data!),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.result});
  final ViewCompetencyResult result;

  @override
  Widget build(BuildContext context) {
    final courses = result.courses;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // CSS ref, confirmed via a live devtools inspection of the
                // real `<h3 class="text-center" style="box-shadow:.5px
                // .5px 6px #6262624d;border-radius:12px;margin-top:10px;
                // margin-bottom:20px;padding:12px;">`: this box-shadow/
                // radius/margin/padding belongs to the HEADING itself,
                // not a separate enclosing "card" wrapping the whole
                // body (the invented white radius-14/shadow Container
                // that used to wrap heading+table together has been
                // removed — the real table sits directly on the page
                // background below it, no card border of its own).
                // Text: `h1..h6{font-weight:500;line-height:1.2}` +
                // `h3,.h3{font-size:1.75rem}` (28px) + Inter via the
                // site-wide `h1..h6,.nav-link,.btn{font-family:var(
                // --primary-font)!important}` — was 20px/w800 with no
                // font-family. Color kept at the inherited body
                // `color:var(--text-main)!important` (#2D3748) since no
                // h3-specific override was found.
                // Design call, not a CSS match: after several rounds
                // of trying to reproduce the real page's near-invisible
                // `0.5px 0.5px 6px #6262624d` shadow (Flutter kept
                // rendering it as a visibly solid grey box no matter how
                // far it was scaled down), the user asked for this
                // strip designed directly instead — a soft, subtly-
                // elevated light-grey card: pale fill, thin hairline
                // border, gentle ambient shadow (heavier below than
                // above, the usual cue for a raised surface).
                // CSS ref: a real mobile screenshot shows a completely
                // different, much more compact heading treatment on
                // phone — small uppercase bold letter-spaced text, no
                // card/shadow — not just a scaled-down version of the
                // desktop 28px heading above.
                if (Responsive.isTablet(context))
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      result.competency.isNotEmpty
                          ? result.competency
                          : 'Competency',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF2D3748),
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      (result.competency.isNotEmpty
                              ? result.competency
                              : 'Competency')
                          .toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1E2939),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                if (courses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No courses found for this competency.',
                      style: TextStyle(color: _vcMuted, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (Responsive.isTablet(context))
                  _CourseTable(courses: courses)
                else
                  _CoursePhoneList(courses: courses),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: AppFooter()),
      ],
    );
  }
}

class _CourseTable extends StatelessWidget {
  const _CourseTable({required this.courses});
  final List<DashboardCourse> courses;

  @override
  Widget build(BuildContext context) {
    // CSS ref, confirmed against `origin/staging`'s dist/app.css: this is
    // a plain kartik `GridView` with no custom column styling — just the
    // base `.table th` override (plain purple TEXT, weight 400, 16px/
    // lh20, border-color #DBE5E9 — was a white→#EEEEEE gradient bar with
    // bold 13px text). Padding corrected `15px → 12px`: the same live-
    // cascade evidence gathered on the Learning Paths tables showed
    // `.table th, .table td{padding:0.75rem}` (12px) winning outright
    // over `.table td, .table th{padding:15px}` — same site-wide rule,
    // so it applies here too. The index (SerialColumn) and course-name
    // columns both have no color/weight override in `_view_competency
    // .php` either — plain body text (was purple/600 and ink/600
    // respectively).
    // CSS ref, corrected: comparing all three header cells live, the
    // ones with no inline style (the "#" and action/View columns)
    // clearly show `.table-bordered th, .table-bordered td{border:1px
    // solid #dee2e6}` WINNING for top/left/right, with only the
    // BOTTOM edge overridden to none by the more specific `.kv-table-
    // header > tr > th{border-bottom:none}`. The one cell that looked
    // borderless on top ("Course Name") turns out to have an INLINE
    // `border-top-style:none` — a Krajee resizable-column JS artifact
    // on that one cell, not a real design rule (inline styles always
    // win regardless of the stylesheet) — the previous round wrongly
    // generalized from it and removed the table's outer top border
    // entirely; restored here. Also corrected the border color itself:
    // `#DBE5E9` (the site override used elsewhere) is shown LOSING in
    // all three of these header-cell dumps — `#dee2e6` (Bootstrap's
    // plain default, via `.table-bordered th/td`) is what actually
    // wins for this table.
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: const TableBorder(
        top: BorderSide(color: Color(0xFFDEE2E6)),
        bottom: BorderSide(color: Color(0xFFDEE2E6)),
        horizontalInside: BorderSide(color: Color(0xFFDEE2E6)),
        verticalInside: BorderSide(color: Color(0xFFDEE2E6)),
      ),
      columnWidths: const {
        0: FixedColumnWidth(56),
        1: FlexColumnWidth(6),
        2: FlexColumnWidth(3),
      },
      children: [
        // CSS ref: same `.kv-table-header{background:linear-gradient(
        // to bottom,#fff 0%,#eee 100%)}` confirmed on the Learning
        // Paths table's header applies here too (live cascade dump on
        // this exact `<thead class="kv-table-header">`) — was no
        // background at all.
        TableRow(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFEEEEEE)],
            ),
          ),
          children: const [
            SizedBox(height: 50),
            Center(
              child: Text(
                'Course Name',
                style: TextStyle(
                  color: _vcPurple,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 20 / 16,
                ),
              ),
            ),
            SizedBox.shrink(),
          ],
        ),
        for (var i = 0; i < courses.length; i++)
          TableRow(
            // CSS ref: real page alternates row background (row 1 has a
            // light-grey stripe, row 2 is plain white — classic
            // Bootstrap `.table-striped`) — was uniform/no row
            // background at all.
            decoration:
                i.isEven ? const BoxDecoration(color: Color(0x0D000000)) : null,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.inter(color: _vcInk, fontSize: 14),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  // Per explicit request: same color as the index, and
                  // matched font size/line-height so both cells in this
                  // row settle at the same height (was 13/13.5px with
                  // an extra 1.4 line-height on this cell only, letting
                  // it run taller than the index cell next to it).
                  child: Text(
                    courses[i].name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: _vcInk, fontSize: 14),
                  ),
                ),
              ),
              Center(child: _ViewButton(course: courses[i])),
            ],
          ),
      ],
    );
  }
}

// Phone layout: a real mobile screenshot shows this competency's
// courses as a plain list of rows (index / name / "View"), not the
// desktop `Table` — no header row, no cell borders, just an
// alternating light-grey stripe per row and a divider-free list.
class _CoursePhoneList extends StatelessWidget {
  const _CoursePhoneList({required this.courses});
  final List<DashboardCourse> courses;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < courses.length; i++)
          Container(
            // CSS ref, confirmed via the browser's own computed-style
            // inspector on the real `<tr>`: striped row background is
            // `rgba(0,0,0,0.05)` — a semi-transparent black overlay,
            // not a solid grey hex — and padding is `16px 20px` (was
            // a solid `#F3F4F6` fill at 14px/12px).
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color:
                  i.isEven
                      ? Colors.black.withValues(alpha: 0.05)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    (i + 1).toString().padLeft(2, '0'),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9AA1AC),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    courses[i].name,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1E2939),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ViewButton(course: courses[i]),
              ],
            ),
          ),
      ],
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({required this.course});
  final DashboardCourse course;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovering) {
        Future<Object?> onPressed() => Modular.to.pushNamed(
          CoursesModule.construct('${CoursesModule.detail}/${course.id}'),
        );
        // Per explicit request: same UI as the Learning Paths page's
        // competency "View" button (`_viewButton` in
        // learning_paths_page.dart) — plain borderless purple link by
        // default, filled purple with white icon/text on hover. Same
        // radius/weight/size/padding (`.btn` site-wide override: radius
        // 8, weight 600, 14px, padding 4px all sides) and filled
        // `remove_red_eye` icon as that button, applied here too.
        const shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        );
        const textStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 14);
        const padding = EdgeInsets.all(4);
        return hovering
            ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(
                Icons.remove_red_eye,
                size: 14,
                color: Colors.white,
              ),
              label: const Text('View'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _vcPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 30),
                padding: padding,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: shape,
                textStyle: textStyle,
              ),
            )
            : TextButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.remove_red_eye, size: 14),
              label: const Text('View'),
              style: TextButton.styleFrom(
                foregroundColor: _vcPurple,
                minimumSize: const Size(0, 30),
                padding: padding,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: shape,
                textStyle: textStyle,
              ),
            );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _vcMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _vcMuted),
            ),
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

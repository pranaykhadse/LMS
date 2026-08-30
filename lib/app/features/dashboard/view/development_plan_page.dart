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
import 'package:lms/app/core/views/elements/pagination_widget.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/view/widgets/course_grid_card.dart';
import 'package:lms/app/features/courses/view/widgets/course_view_availability.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/viewmodel/development_plan_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;
const _titleColor = Color(0xFFA20067);
// CSS ref, confirmed via a live devtools cascade dump on the "Non
// Course Development Plan"/"Status Update" modal inputs: the winning
// `:where(input[type=text],...)` rule sets `color:var(--text-main)
// !important` (0xFF2D3748) and `border:1px solid var(--border-light)
// !important` (0xFFE2E8F0) — neither matches an existing FigmaTokens
// entry (cardBorders/0xFFE5E7EB is close but not the same var).
const _inputText = Color(0xFF2D3748);
const _inputBorder = Color(0xFFE2E8F0);

class DevelopmentPlanPage extends ConsumerWidget {
  const DevelopmentPlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(DevelopmentPlanViewModel.provider);
    final notifier = ref.read(DevelopmentPlanViewModel.provider.notifier);

    return AppScaffold(
      backgroundColor: _bg,
      title: 'My Development Plan',
      selectedSubLabel: 'My Development Plan',
      onRefresh: () => notifier.fetch(page: state.page),
      body: _Body(state: state, notifier: notifier),
    );
  }
}

// The original card-grid layout (below, _CourseCard/GridView) is kept in
// this file but no longer reachable from the UI - the table layout (now
// used on every device, phone included - see _DevelopmentPlanTable/
// _TableDataRow's own phone/tablet+ split) is the only design shown. Kept
// around in case the grid layout is needed again later rather than
// deleted outright.

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.notifier});
  final DevelopmentPlanState state;
  final DevelopmentPlanViewModel notifier;

  @override
  Widget build(BuildContext context) {
    switch (state.providerState) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(child: CircularProgressIndicator(color: _purple));
      case DataProviderState.error:
        return _ErrorView(
          message: friendlyErrorMessage(
            state.error,
            'Unable to load development plan.',
          ),
          onRetry: () => notifier.fetch(),
        );
      case DataProviderState.data:
        // Design ref, confirmed against the live DOM (same pattern as
        // every other My Courses screen): #pagination flows as the last
        // child inside the same `.structure-block` white card — it
        // scrolls with the content, it isn't pinned outside the scroll
        // area as a fixed footer.
        return RefreshIndicator(
          color: _purple,
          onRefresh: () async {
            await notifier.fetch(page: state.page);
          },
          child: Builder(
            builder: (context) {
              // CSS ref, confirmed against `origin/staging`'s
              // my-development-plan/index.php own inline <style>:
              // `@media (max-width: 768px) { .structure-block { padding:
              // 15px 10px !important; margin-top: 10px; } }` — a
              // page-specific override, different from the flat 20px
              // used elsewhere. Was ignoring this entirely.
              final narrow = MediaQuery.sizeOf(context).width <= 768;
              return ListView(
                padding: EdgeInsets.fromLTRB(16, narrow ? 26 : 16, 16, 0),
                children: [
                  Container(
                    // Design ref, confirmed against live computed style:
                    // this table sits inside the same `.structure-block`
                    // white card as every other My Courses screen — bg
                    // #fff, radius 16px, border 0.8px solid #E7E4FF, no
                    // box-shadow (not the 12px-radius/shadow card this
                    // previously used).
                    padding:
                        narrow
                            ? const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 15,
                            )
                            : const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      // CSS ref: .structure-block { border: 1px solid
                      // #E7E4FF }.
                      border: Border.all(color: const Color(0xFFE7E4FF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CSS ref, confirmed against `origin/staging`'s
                        // my-development-plan/index.php: this page has no
                        // `#my-courses`/`#resources`-scoped title (unlike
                        // every other My Courses screen) — its markup is
                        // a bare `<h2 class="title mb-0">` inside
                        // `<div class="sec-title" style="margin-bottom:
                        // 20px;gap:15px">`. None of `dist/app.css`'s
                        // `#my-courses .sec-title h2`/`#resources .sec-
                        // title h2` rules apply (they're ID-scoped to
                        // different pages) — this h2 falls through to the
                        // generic Bootstrap heading rules instead: `h2{
                        // font-size:2rem}` + `h1..h6{font-weight:500;
                        // line-height:1.2}`, color unset (inherits body's
                        // #2A2A2A) — was wrongly #2D3748 with no
                        // real basis. `.mb-0` zeroes the h2's own margin;
                        // the real gap before the table is the `.sec-
                        // title` div's own inline `margin-bottom:20px` —
                        // was wrongly 8px wrapping just this row.
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Builder(
                            builder: (context) {
                              final title = Text(
                                'My Development Plan',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF2A2A2A),
                                  fontSize: 32,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                              );
                              // CSS ref, corrected via a live devtools
                              // full-cascade dump: this button ALSO
                              // matches a site-wide, `!important`
                              // override — `.btn,button,input[type=
                              // submit],...{font-family:var(--primary-
                              // font)!important;border-radius:8px
                              // !important;font-weight:600!important;
                              // font-size:14px!important;padding:4px 4px
                              // !important;border:none!important}` —
                              // which beats the vanilla `.btn-primary`
                              // values (padding 5px 20px, 16px/w400,
                              // radius 4px, a visible border) this had
                              // been using. Also picks up `button.btn{
                              // letter-spacing:1px}` (survives, not
                              // touched by the override). Confirmed
                              // exactly by the live box model: 195.39×29
                              // total, 4px padding all sides, 187.387×21
                              // content (21px = the real `.btn{line-
                              // height:21px}`, which the override
                              // doesn't touch either). `.btn-primary,
                              // .btn-purple,.btn-default{background:var(
                              // --primary-color)!important;color:white
                              // !important}` confirms the fill/text
                              // color (already correct) — no visible
                              // border at all (`border:none!important`
                              // wins), so the hover border added earlier
                              // was never real either.
                              //
                              // Hover ref: also found `bluetheme-layout
                              // .css`'s OWN `.btn-primary:hover{
                              // background:var(--primary-dark)
                              // !important; box-shadow:var(--shadow-md)
                              // !important; transform:translateY(-1px)}`
                              // — loaded AFTER `dist/app.css` with
                              // `!important`, so it wins over that
                              // file's `.btn-primary:hover{background:
                              // #4043AF}` this had been using (a Round
                              // 29 finding that turns out to only be
                              // correct in isolation, not against this
                              // later override). `--primary-dark`=
                              // `#5A3480` — the same `FigmaTokens
                              // .purpleHover` token used everywhere else
                              // in the app, not a bespoke color.
                              final addButton = HoverBuilder(
                                builder:
                                    (context, hovering) => AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      transform: Matrix4.translationValues(
                                        0,
                                        hovering ? -1 : 0,
                                        0,
                                      ),
                                      decoration: BoxDecoration(
                                        boxShadow:
                                            hovering
                                                ? [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.1),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ]
                                                : null,
                                      ),
                                      child: ElevatedButton(
                                        onPressed:
                                            () => _showAddPlanItemDialog(
                                              context,
                                              notifier,
                                            ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              hovering
                                                  ? FigmaTokens.purpleHover
                                                  : _purple,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          // Padding adjusted per
                                          // explicit user request (a
                                          // deliberate deviation from
                                          // the real 4px, not a
                                          // web-match fix).
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 14,
                                          ),
                                          side: BorderSide.none,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          textStyle: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            height: 21 / 14,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        // Built as a plain `ElevatedButton`
                                        // with a manual `Row` instead of
                                        // `.icon(...)` — the icon+label
                                        // constructor lays the label out
                                        // via its own internal padding/
                                        // baseline rules, which was
                                        // reading as vertically off-
                                        // center against the icon.
                                        // `crossAxisAlignment.center`
                                        // aligns both by their layout
                                        // box instead of by text baseline.
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_rounded, size: 14),
                                            SizedBox(width: 8),
                                            Text('Add Custom Plan Item'),
                                          ],
                                        ),
                                      ),
                                    ),
                              );
                              // Phone: "Add Custom Plan Item" doesn't fit
                              // next to the title in a Row (overflowed by
                              // 38px) - stack title above a full-width
                              // button instead. CSS ref: the real `.sec-
                              // title`'s own `gap:15px` governs the space
                              // between the wrapped title/button here too
                              // (flex `gap` applies across wrapped lines,
                              // not just `justify-content:space-between`'s
                              // one-line case below) — was 12px.
                              if (!Responsive.isTablet(context)) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    title,
                                    const SizedBox(height: 15),
                                    SizedBox(
                                      width: double.infinity,
                                      child: addButton,
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [title, addButton],
                              );
                            },
                          ),
                        ),
                        if (state.courses.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40, bottom: 40),
                            child: _EmptyState(),
                          )
                        // Same table on every device - _DevelopmentPlanTable
                        // switches its own row layout between a stacked
                        // phone card and the full multi-column row for
                        // tablet+ (see _TableDataRow), instead of phone
                        // getting an unrelated image-grid design.
                        else
                          _DevelopmentPlanTable(
                            courses: state.courses,
                            notifier: notifier,
                            startIndex: (state.page - 1) * state.perPage + 1,
                          ),
                        if (state.courses.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          PaginationWidget(
                            page: state.page,
                            pages: state.totalPages,
                            onPage: (page) => _goToPage(context, page),
                            showProgressBar: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AppFooter(),
                ],
              );
            },
          ),
        );
    }
  }

  void _goToPage(BuildContext context, int page) {
    notifier.goToPage(page).then((error) {
      if (error != null && context.mounted) Toast.error(context, error);
    });
  }
}

void _showAddPlanItemDialog(
  BuildContext context,
  DevelopmentPlanViewModel notifier,
) {
  showDialog(
    context: context,
    builder:
        (dialogContext) => _AddPlanItemDialog(
          onAdd: (name) async {
            final result = await notifier.addCustomPlanItem(name);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (!context.mounted) return;
            if (result.success) {
              Toast.success(
                context,
                result.message ?? 'Plan item added successfully.',
              );
            } else {
              Toast.error(
                context,
                result.message ?? 'Unable to add plan item.',
              );
            }
          },
        ),
  );
}

// ─── Add custom plan item dialog ───────────────────────────────────────────────

class _AddPlanItemDialog extends StatefulWidget {
  const _AddPlanItemDialog({required this.onAdd});
  final Future<void> Function(String name) onAdd;

  @override
  State<_AddPlanItemDialog> createState() => _AddPlanItemDialogState();
}

class _AddPlanItemDialogState extends State<_AddPlanItemDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    await widget.onAdd(name);
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return _PlanItemModalChrome(
      title: 'Non Course Development Plan',
      // Height ref: real `.form-control{height:42px}`, confirmed both
      // via devtools AND by re-checking `origin/staging`'s
      // `my-development-plan/index.php` source directly — no page-
      // specific override exists, 42px genuinely is the real, complete
      // value. `InputDecoration.constraints` wasn't reliably forcing
      // growth against `contentPadding`/text height, so this box is a
      // hard-pinned `SizedBox` + plain `Container` instead — after
      // several deliberate deviations that overshot in the other
      // direction (46/48/54), settled back on the real 42px, which is
      // what actually reads correctly once rendered.
      body: SizedBox(
        height: 42,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _inputBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: GoogleFonts.inter(
              color: _inputText,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: 'Enter Name of Development Plan Item',
              hintStyle: const TextStyle(color: _muted, fontSize: 13),
            ),
          ),
        ),
      ),
      submitLabel: 'Add',
      submitting: _submitting,
      onSubmit: _submit,
    );
  }
}

// CSS ref, confirmed via a full live-devtools cascade dump on this
// exact modal (real markup: `.modal-header`+`.close`+`.modal-title`
// h4 +`.modal-body`+`.modal-footer` with a plain `.btn.btn-primary`) —
// the SAME real chrome already traced for the Calendar screen's Event
// Details modal (docs/course-catalog-ui-audit.md, Rounds 29-37). This
// dialog was previously a plain invented card (16px radius, no
// border, 17px/w800 title, full-width 44px-tall button) with none of
// that. Real values: `.modal-content{border:1px solid #693D94;
// border-radius:24px;padding:15px}` (no `modal-lg` here, so `.modal-
// dialog{max-width:500px}` caps it — a smaller dialog than the
// Calendar's 80vw/800px one). `.modal-header` — own 16px padding
// (confirmed: 468.4×61 measured, `display:block!important;text-align:
// center`). `.modal-title` — 24px/w400/#606060/line-height 28,
// centered. `.close` — 18px, color #2A2A2A@0.5 opacity (0.75 on
// hover), 4px padding, no visible border. `.modal-body{margin:0 20px;
// padding:0!important}`. `.modal-footer{display:block!important;
// text-align:center}` — centered, single button. The "Add"/"Update"
// button is the SAME real `.btn.btn-primary` traced in Round 36 —
// 4px padding, radius 8px, weight 600, font-size 14px, no border,
// hover `var(--primary-dark)`=`FigmaTokens.purpleHover` with a
// shadow+lift — not the old flat purple/44px-tall/full-width button.
class _PlanItemModalChrome extends StatelessWidget {
  const _PlanItemModalChrome({
    required this.title,
    required this.body,
    required this.submitLabel,
    required this.submitting,
    required this.onSubmit,
  });
  final String title;
  final Widget body;
  final String submitLabel;
  final bool submitting;
  final VoidCallback onSubmit;

  Widget _closeIcon(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder:
          (context, hovering) => IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.close_rounded,
              color: const Color(
                0xFF2A2A2A,
              ).withValues(alpha: hovering ? 0.75 : 0.5),
              size: 18,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // App-only layout choice (not a web-match value, there's no mobile
    // breakpoint on the real `.modal-dialog`): below the same <=768
    // phone threshold used elsewhere in this file, the modal gets a
    // wider dialog (smaller side insets) and a stacked header — close
    // icon on its own row above a full-width title — per explicit
    // request, instead of the desktop header's icon-overlapping-title
    // `Stack`.
    final isMobile = MediaQuery.sizeOf(context).width <= 768;
    return Dialog(
      // Positioning ref: same as Calendar's Event Details modal — the
      // real `.modal-dialog` sits just below the purple top bar, not
      // vertically centered; `top:44` clears exactly the purple bar
      // (`--nav-height:44px`), not the whole white nav row beneath it.
      alignment: Alignment.topCenter,
      insetPadding: EdgeInsets.only(
        top: 44,
        left: isMobile ? 16 : 40,
        right: isMobile ? 16 : 40,
        bottom: 24,
      ),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: _purple),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  // CSS ref: the real mobile modal centers the close
                  // icon above the title rather than pinning it to the
                  // right corner — Bootstrap's base `.close{float:
                  // right}` is never overridden here, but the real
                  // page's own screenshot (same iPhone SE viewport)
                  // shows it dead-center regardless, so this follows
                  // that rendered evidence rather than the source's
                  // float rule. `SizedBox(width: double.infinity)` is
                  // still needed — without it, a plain `Column` sizes
                  // itself to its widest child (the title text)
                  // instead of the full available width, so `Align`
                  // was centering within that narrower box rather than
                  // the header's true width.
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: _closeIcon(context),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF606060),
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              height: 28 / 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 31,
                    vertical: 16,
                  ),
                  // `SizedBox(width: double.infinity)` forces the Stack
                  // to the header's full available width — a bare
                  // `Stack` sizes itself to its non-positioned child
                  // (the title `Text`), so once the title wraps to two
                  // lines it would otherwise shrink to that text's own
                  // (narrower) content width, dragging the `Positioned
                  // (right:0)` close icon in from the true right edge.
                  child: SizedBox(
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Padding leaves room for the close icon so a
                        // wrapped two-line title doesn't run under it.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 26),
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF606060),
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              height: 28 / 24,
                            ),
                          ),
                        ),
                        Positioned(right: 0, child: _closeIcon(context)),
                      ],
                    ),
                  ),
                ),
              // CSS ref, confirmed via live devtools box-model measurement
              // (468.4 modal-content width - 428.4 .modal-body width = 40,
              // i.e. 20px each side): real rule is `.modal-body{margin:0
              // 20px;padding:0!important}` — was wrongly copied from the
              // Calendar Event Details modal's own 35px value, which is a
              // different, page-specific override that doesn't apply here.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: body,
              ),
              const SizedBox(height: 20),
              Center(
                child: HoverBuilder(
                  cursor:
                      submitting
                          ? SystemMouseCursors.basic
                          : SystemMouseCursors.click,
                  builder: (context, hovering) {
                    final bg =
                        hovering && !submitting
                            ? FigmaTokens.purpleHover
                            : _purple;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      transform: Matrix4.translationValues(
                        0,
                        hovering && !submitting ? -1 : 0,
                        0,
                      ),
                      decoration: BoxDecoration(
                        boxShadow:
                            hovering && !submitting
                                ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                                : null,
                      ),
                      child: Material(
                        color: bg.withValues(alpha: submitting ? 0.6 : 1),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: submitting ? null : onSubmit,
                          child: Padding(
                            // CSS ref: the real winning rule is the
                            // site-wide `.btn,button,input[type=submit]
                            // {padding:4px 4px!important}` (Round 36).
                            // Bumped up a bit per an explicit follow-up
                            // request — a deliberate deviation, same as
                            // Calendar's Close/View Course buttons and
                            // the "Add Custom Plan Item" button.
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child:
                                submitting
                                    ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : Text(
                                      submitLabel,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        height: 21 / 14,
                                        letterSpacing: 1,
                                      ),
                                    ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}

void _showUpdatePlanItemDialog(
  BuildContext context,
  DevelopmentPlanViewModel notifier,
  DashboardCourse course,
) {
  showDialog(
    context: context,
    builder:
        (dialogContext) => _UpdatePlanItemDialog(
          onUpdate: (percentage) async {
            final result = await notifier.updateCustomPlanItem(
              course.id,
              percentage,
            );
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (!context.mounted) return;
            if (result.success) {
              Toast.success(
                context,
                result.message ?? 'Plan item updated successfully.',
              );
            } else {
              Toast.error(
                context,
                result.message ?? 'Unable to update plan item.',
              );
            }
          },
        ),
  );
}

// ─── Update custom plan item dialog ────────────────────────────────────────────

class _UpdatePlanItemDialog extends StatefulWidget {
  const _UpdatePlanItemDialog({required this.onUpdate});
  final Future<void> Function(int percentage) onUpdate;

  @override
  State<_UpdatePlanItemDialog> createState() => _UpdatePlanItemDialogState();
}

class _UpdatePlanItemDialogState extends State<_UpdatePlanItemDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final percentage = int.tryParse(_controller.text.trim());
    if (percentage == null || percentage < 0 || percentage > 100) {
      setState(() => _error = 'Enter a value between 0 and 100');
      return;
    }
    if (_submitting) return;
    setState(() {
      _error = null;
      _submitting = true;
    });
    await widget.onUpdate(percentage);
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return _PlanItemModalChrome(
      title: 'Status Update',
      // Height ref: see `_AddPlanItemDialogState`'s own body — same
      // hard-pinned `Container` swap, same reasoning (real 42px value
      // confirmed both via devtools and the `origin/staging` source,
      // but `InputDecoration.constraints` wasn't reliably forcing
      // growth, so this is a deliberate deviation). The real markup's
      // `<p class="help-block help-block-error">` below the input is
      // now its own `Text` (real `.help-block-error{color:#ff0000}`)
      // instead of `InputDecoration.errorText`, since the borderless
      // decoration no longer has its own error-row layout.
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 42,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _inputBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: GoogleFonts.inter(
                  color: _inputText,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Status (in percentage)',
                  hintStyle: const TextStyle(color: _muted, fontSize: 13),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFF0000), fontSize: 12),
              ),
            ),
        ],
      ),
      submitLabel: 'Update',
      submitting: _submitting,
      onSubmit: _submit,
    );
  }
}

// ─── Development plan table ─────────────────────────────────────────────────

class _DevelopmentPlanTable extends StatelessWidget {
  const _DevelopmentPlanTable({
    required this.courses,
    required this.notifier,
    required this.startIndex,
  });
  final List<DashboardCourse> courses;
  final DevelopmentPlanViewModel notifier;
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    // CSS ref, confirmed against `origin/staging`'s
    // backend/views/my-development-plan/index.php own inline <style>:
    // `@media (max-width: 768px) { .table-responsive table thead {
    // display: none } ... }` — the table-to-stacked-cards switch is at
    // 768px, not `Responsive.tablet`'s 700px (widths 700-768 were wrongly
    // showing the multi-column row instead of stacked cards).
    final isPhone = MediaQuery.sizeOf(context).width <= 768;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CSS ref: this table shares the same generic `.table`/`.table
        // thead th` rules as Learning Paths/View Competency (see
        // docs/course-catalog-ui-audit.md, Round 7) — border color
        // #DBE5E9 (was the generic app-wide cardBorders token, #E5E7EB,
        // a different hue entirely) — missed when those two tables were
        // rebuilt since this screen wasn't re-checked at the time.
        //
        // Divider ref, confirmed against a live screenshot of the real
        // page: there is exactly ONE divider line on the whole table —
        // right under the header row. Data rows have no divider (or any
        // other border) between them at all, just whitespace — was
        // wrongly adding one between every single row.
        if (!isPhone) ...[
          const _TableHeaderRow(),
          const Divider(height: 1, color: Color(0xFFDBE5E9)),
        ],
        for (var i = 0; i < courses.length; i++)
          _TableDataRow(
            index: startIndex + i,
            course: courses[i],
            notifier: notifier,
          ),
      ],
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();

  @override
  Widget build(BuildContext context) {
    // CSS ref: two competing `dist/app.css .table td, .table th{padding:
    // 15px}` (earlier) / `.table th, .table td{padding:.75rem(12px)}`
    // (later, in the same file, same specificity — later wins) rules
    // exist; the later one governs. Was 15px (may also affect Learning
    // Paths/View Competency's own tables — flagged, not re-checked here).
    //
    // Each real `<th>` carries this 12px padding on ALL sides
    // individually (not just the row as a whole) — adjacent cells'
    // padding sums to a 24px visual gutter between columns. Was a
    // single outer `Padding(all:12)` wrapping the whole row, leaving
    // columns with no gap between them at all beyond their flex ratio.
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // CSS ref: the `#` column's real inline width is 40px (was
          // 32px) — box-sizing:border-box means the 12px/side cell
          // padding eats into that 40px total, not added on top.
          SizedBox(
            width: 40,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: _HeaderCell('#', bold: true, center: true),
            ),
          ),
          Expanded(
            // Width ratio live-measured via devtools on the real page
            // (Group 309.59 / Course 656.69 / Status 143.59 / Action
            // 312.14, out of 1422.01 total flexible width) — simplifies
            // to flex 11:23:5:11. Replaces the earlier ad hoc "deliberate
            // deviation" ratios from prior rounds with the real one.
            flex: 11,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: _HeaderCell('Group'),
            ),
          ),
          Expanded(
            flex: 23,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: _HeaderCell('Course'),
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: _HeaderCell('Status'),
            ),
          ),
          Expanded(flex: 11, child: SizedBox()),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {this.bold = false, this.center = false});
  final String label;
  final bool bold;
  final bool center;

  @override
  Widget build(BuildContext context) {
    // CSS ref: `.table th` — font-weight 400 (not 600 — only the `#`
    // column's own inline style is bold), font-size 16px, line-height
    // 20px, color var(--primary-first)=#693D94. Block2 (later in dist/
    // app.css) doesn't touch these text properties, only padding/
    // border, so they're uncontested.
    return Text(
      label,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        color: _purple,
        fontSize: 16,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        height: 20 / 16,
      ),
    );
  }
}

class _TableDataRow extends ConsumerWidget {
  const _TableDataRow({
    required this.index,
    required this.course,
    required this.notifier,
  });
  final int index;
  final DashboardCourse course;
  final DevelopmentPlanViewModel notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewDisabled =
        !course.isNonCourse && isViewCourseDisabled(ref, course.id);
    final group =
        course.isNonCourse
            ? 'Non Course Development Plan'
            : (course.category?.isNotEmpty == true
                ? course.category!
                : 'Course');
    final onPressed =
        course.isNonCourse
            ? () => _showUpdatePlanItemDialog(context, notifier, course)
            : viewDisabled
            ? null
            : () => Modular.to.pushNamed(
              CoursesModule.construct('${CoursesModule.detail}/${course.id}'),
            );
    // CSS ref, corrected via a live devtools full-cascade dump: the real
    // action link is NOT a bare unstyled `<a>` (a Round 31 conclusion
    // that turns out wrong) — its actual class is `btn btn-lg btn-
    // outline-primary my-1`. Real computed style: `.btn-lg{padding:14px
    // 28px!important;font-size:16px!important}` (wins over the site-
    // wide `.btn,button,...{padding:4px 4px;font-size:14px}` override —
    // confirmed exactly by the live box model: 154.45×52 total, 14px/
    // 28px padding, 98.45×24 content), `border-radius:8px!important`
    // (from that same site-wide rule, untouched by `.btn-lg`),
    // `font-weight:600!important` (ditto), `line-height:1.5` (survives
    // from Bootstrap's own `.btn-lg` block, since the custom `.btn-lg`
    // override doesn't set its own), `.btn-outline-primary{color:var(
    // --primary-first)=#693D94!important}`, `.btn{background-color:
    // transparent}` (never overridden — this is a genuinely transparent
    // outline button, not a solid fill), `border:none!important`
    // (site-wide — so no visible border ever, despite `.btn-outline-
    // primary`'s own border-color rule existing). `.my-1{margin-top/
    // bottom:.25rem(4px)!important}`. On hover: no override for `.btn-
    // outline-primary:hover` exists in any stylesheet checked, so
    // Bootstrap's own default applies — fills solid `#693D94`, text
    // turns white.
    Widget buildActionButton({bool compact = false}) {
      return HoverBuilder(
        cursor:
            onPressed == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
        builder:
            (context, hovering) => Material(
              color: hovering ? _purple : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onPressed,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  // Size decreased for mobile per explicit user request
                  // (a deliberate deviation from the real 28px/14px
                  // padding + 16px text, not a web-match fix).
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 14 : 28,
                    vertical: compact ? 8 : 14,
                  ),
                  child: Text(
                    course.isNonCourse ? 'Update' : 'View Course',
                    style: GoogleFonts.inter(
                      color: hovering ? Colors.white : _purple,
                      fontSize: compact ? 13 : 16,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
      );
    }

    final actionButton = buildActionButton();

    // CSS ref, confirmed against a real mobile screenshot AND `my-
    // development-plan/index.php`'s own inline `<style>`'s `@media
    // (max-width:768px) .table-responsive table tr/td/td::before`
    // block: on mobile, GridView's native table doesn't reflow into a
    // custom app card at all — it's the SAME `<table>` with CSS turning
    // each `<tr>` into a label:value card (`display:block`, radius
    // 12px, `box-shadow:0 4px 15px rgba(0,0,0,.05)`, padding 15px,
    // border 1px solid #f0f1f5) and each `<td>` into a flex row
    // (`justify-content:space-between`, its own `data-label` shown via
    // `::before` — bold/#64748B — on the left, the real cell content
    // right-aligned, a 1px #f0f1f5 border-bottom between fields except
    // the last). Was an invented "#N / group inline, then bold title,
    // then Status: X% + action" layout with none of the real per-field
    // label:value rows, background/shadow, or borders.
    if (MediaQuery.sizeOf(context).width <= 768) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0F1F5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _mobileFieldRow('#', Text('$index', style: _mobileValueStyle)),
            _mobileFieldRow('Group', Text(group, style: _mobileValueStyle)),
            _mobileFieldRow(
              'Course',
              Text(
                course.name,
                textAlign: TextAlign.right,
                style: _mobileValueStyle,
              ),
            ),
            _mobileFieldRow(
              'Status',
              Text(
                course.notEnrolled ? 'Not Enrolled' : '${course.progress}%',
                style: _mobileValueStyle,
              ),
            ),
            _mobileFieldRow(
              'Action',
              buildActionButton(compact: true),
              isLast: true,
            ),
          ],
        ),
      );
    }

    // CSS ref: same later-wins `.table th, .table td{padding:.75rem
    // (12px)}` rule the header row uses (was 15px). Data-cell text isn't
    // touched by either `.table td, .table th` block — it inherits
    // `.table{color:#212529}` (Block2, later in dist/app.css) and body's
    // real font-size:14px!important (see docs/course-catalog-ui-audit
    // .md, Round 29's body-font-size finding) — was #1E2939 (`_ink`, a
    // different token with no real basis here)/13px. None of these
    // columns' PHP `value` closures apply any bold/weight styling to the
    // Course column either — was wrongly weight 600.
    //
    // Each real `<td>` carries this 12px padding on ALL sides
    // individually (not just the row as a whole) — same fix as the
    // header row, applied per-column instead of once around the row.
    //
    // Row height ref, live-measured via devtools on two different real
    // rows (`Group` cell, `Course` cell): both report the exact same
    // 84.8px `<td>` height regardless of row/column — i.e. every row
    // shares one uniform height (HTML tables give every cell in a row
    // the same height, and this table apparently keeps every ROW the
    // same height as every other row too). Flutter's `Row` only
    // naturally equalizes cells WITHIN one row (via `CrossAxisAlignment
    // .center` sizing to the tallest child) — it doesn't equalize
    // ACROSS rows, so shorter single-line rows here were only ~45px
    // (12+12 padding + ~21px text), well under the real 84.8px.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 84.8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // CSS ref: the `#` column's own `contentOptions` inline style
            // is `text-align:center` for DATA cells too, not just its
            // header — was left-aligned. No color/weight override for the
            // data cells specifically (unlike the header's own bold), so
            // it's the same plain #212529/14px/400 as every other column.
            // Width 40px (was 32px), box-sizing:border-box so the 12px/
            // side padding eats into it rather than adding on top — same
            // fix as the header row's `#` column.
            SizedBox(
              width: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$index',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF212529),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Expanded(
              // Width ratio live-measured via devtools on the real page
              // — matches the header row's own flex:11 (see there for
              // the full measurement).
              flex: 11,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  group,
                  style: const TextStyle(
                    color: Color(0xFF212529),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 23,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  course.name,
                  style: const TextStyle(
                    color: Color(0xFF212529),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  course.notEnrolled ? 'Not Enrolled' : '${course.progress}%',
                  style: const TextStyle(
                    color: Color(0xFF212529),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 11,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: actionButton,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// CSS ref: `.table-responsive table td` (real value color) — no
// specific override for this field text on mobile beyond `.table{
// color:#212529}`.
const _mobileValueStyle = TextStyle(color: Color(0xFF212529), fontSize: 14);

// CSS ref: `.table-responsive table td` — flex row, space-between,
// right-aligned value; `td::before{content:attr(data-label);font-
// weight:600;color:#64748b}` — the label; `border-bottom:1px solid
// #f0f1f5` between fields, none on the last (`td:last-child{border-
// bottom:0}`); `padding:12px 8px!important` per field.
Widget _mobileFieldRow(String label, Widget value, {bool isLast = false}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration:
        isLast
            ? null
            : const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF0F1F5))),
            ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(child: Align(alignment: Alignment.centerRight, child: value)),
      ],
    ),
  );
}

// ─── Course card ─────────────────────────────────────────────────────────────

class _CourseCard extends ConsumerWidget {
  const _CourseCard({required this.course, required this.notifier});
  final DashboardCourse course;
  final DevelopmentPlanViewModel notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewDisabled =
        !course.isNonCourse && isViewCourseDisabled(ref, course.id);
    return CourseGridCard(
      imageUrl: course.logo,
      title: course.name,
      buttonLabel: course.isNonCourse ? 'Update' : 'View Course',
      onPressed:
          course.isNonCourse
              ? () => _showUpdatePlanItemDialog(context, notifier, course)
              : viewDisabled
              ? null
              : () => Modular.to.pushNamed(
                CoursesModule.construct('${CoursesModule.detail}/${course.id}'),
              ),
      offlineCourse:
          course.isNonCourse
              ? null
              : Course(
                id: course.id,
                name: course.name,
                logoLink: course.logo,
                averageRating: course.averageRating,
                ratingCount: course.ratingCount,
                displayRating: course.displayRating ? 1 : 0,
              ),
      infoSection: _buildInfoSection(course),
      progress: course.progress,
    );
  }

  Widget? _buildInfoSection(DashboardCourse course) {
    final showStars = course.displayRating && course.ratingCount > 0;
    if (!showStars) return null;
    return _StarRow(rating: course.averageRating, count: course.ratingCount);
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
            return const Icon(
              Icons.star_rounded,
              color: Color(0xFFFFC107),
              size: 15,
            );
          }
          if (i < rating) {
            return const Icon(
              Icons.star_half_rounded,
              color: Color(0xFFFFC107),
              size: 15,
            );
          }
          return const Icon(
            Icons.star_border_rounded,
            color: Color(0xFFFFC107),
            size: 15,
          );
        }),
        const SizedBox(width: 4),
        Text(
          '${rating.toStringAsFixed(1)} ($count)',
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF0ECFF),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.timeline_outlined,
                color: _purple,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Development Plan',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your development plan courses will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

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
            const Icon(Icons.error_outline, color: _muted, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
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

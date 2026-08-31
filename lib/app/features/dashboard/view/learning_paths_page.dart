import 'package:flutter/material.dart';
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
import 'package:lms/app/features/dashboard/model/learning_path.dart';
import 'package:lms/app/features/dashboard/view/widgets/offline_courses_section.dart'
    show isEffectivelyOffline;
import 'package:lms/app/features/dashboard/view/view_competency_page.dart';
import 'package:lms/app/features/dashboard/viewmodel/learning_paths_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
// CSS ref, confirmed via the browser's own computed-style inspector
// popover on the real `<td class="w0">` (the "Learning Path for
// Group 1" cell): `color:#212529` — was `FigmaTokens.cardTitles`
// (`#1E2939`), a different, visually-similar dark shade that made
// this table's body text look inconsistently grey/black against
// itself and the rest of the row. Every body-text usage in this file
// already shares this one constant, so fixing it here corrects the
// whole table (path name/index/group, competency name/index/courses/
// type) at once.
const _ink = Color(0xFF212529);
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;
// CSS ref, confirmed via a live devtools cascade dump on the real
// `.structure-block h1`: `color:var(--primary-second)` = `#A20067` —
// was wrongly `#B0006D`, a visually-similar but different, unconfirmed
// value.
const _sectionTitle = Color(0xFFA20067);
// CSS ref, confirmed via a live devtools cascade dump on this exact
// input: the winning `:where(input[type=text],...)` rule sets `color:
// var(--text-main)!important` (0xFF2D3748) and `border:1px solid var(
// --border-light)!important` (0xFFE2E8F0) — neither matches an
// existing FigmaTokens entry.
const _inputText = Color(0xFF2D3748);
const _inputBorder = Color(0xFFE2E8F0);

void _openViewCompetency(
  BuildContext context, {
  required int learningPathId,
  required String competency,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder:
          (_) => ViewCompetencyPage(
            learningPathId: learningPathId,
            competency: competency,
          ),
    ),
  );
}

class LearningPathsPage extends ConsumerStatefulWidget {
  const LearningPathsPage({super.key});

  @override
  ConsumerState<LearningPathsPage> createState() => _LearningPathsPageState();
}

class _LearningPathsPageState extends ConsumerState<LearningPathsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    ref
        .read(LearningPathsViewModel.provider.notifier)
        .fetch(
          name:
              _searchController.text.trim().isEmpty
                  ? null
                  : _searchController.text.trim(),
        );
  }

  void _onReset() {
    _searchController.clear();
    ref.read(LearningPathsViewModel.provider.notifier).fetch();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(LearningPathsViewModel.provider);
    final notifier = ref.read(LearningPathsViewModel.provider.notifier);

    return AppScaffold(
      backgroundColor: _bg,
      title: 'Learning Paths',
      selectedLabel: 'Learning Paths',
      onRefresh:
          () => notifier.fetch(
            name:
                _searchController.text.trim().isEmpty
                    ? null
                    : _searchController.text.trim(),
          ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            onSearch: _onSearch,
            onReset: _onReset,
          ),
          Expanded(child: _Body(state: state, onRetry: () => notifier.fetch())),
        ],
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar({
    required this.controller,
    required this.onSearch,
    required this.onReset,
  });
  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback onReset;

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  bool _hasText = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    // Search hits the live API with no offline fallback - offering it while
    // there's no real connection just invites a tap that can only fail, the
    // same reasoning as RetryButton (see lib/app/core/views/elements).
    final offline = isEffectivelyOffline(ref);
    final isTablet = Responsive.isTablet(context);

    // Design ref, per explicit request: reuses the Course Catalog search
    // field's own visual treatment (`_fieldDecoration`/`_SearchField` in
    // courses_page.dart) — filled #F8FAFC (white when focused), radius 12,
    // #E2E8F0 border (purple 1.5px when focused, plus a soft focus glow the
    // real `.search-blcok .searchInput:focus` box-shadow also has), 18px
    // muted-grey search icon, letter-spacing 1 — instead of this screen's
    // own real (but visually inconsistent) CSS from Round 43.
    final searchField = Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: SizedBox(
        height: 42,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow:
                _focused
                    ? [
                      BoxShadow(
                        color: const Color(0xFF5457C1).withValues(alpha: 0.1),
                        spreadRadius: 4,
                      ),
                    ]
                    : null,
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                hoverColor: Colors.transparent,
              ),
            ),
            child: TextField(
              controller: widget.controller,
              enabled: !offline,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => widget.onSearch(),
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.inter(
                color: _inputText,
                fontSize: 14,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              decoration: InputDecoration(
                // CSS/markup ref, confirmed against
                // `origin/staging`'s course_learning_path.php:
                // placeholder text is literally "Search
                // Learning Path" (singular, title case).
                hintText: offline ? "You're offline" : 'Search Learning Path',
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFF6C757D),
                  fontSize: 15,
                  letterSpacing: 1.0,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
                suffixIcon:
                    _hasText && !offline
                        ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: _muted,
                            size: 20,
                          ),
                          onPressed: () {
                            widget.controller.clear();
                            widget.onSearch();
                          },
                        )
                        : null,
                filled: true,
                // Always white, per explicit request — Course
                // Catalog's own field swaps #F8FAFC->white on
                // focus, but this one should stay white
                // regardless of focus state.
                fillColor: Colors.white,
                hoverColor: Colors.transparent,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _purple, width: 1.5),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _inputBorder),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // CSS ref, confirmed via a live devtools cascade dump on the
    // real `<a class="btn btn-primary undo-btn"><i class="fa
    // fa-undo"></i></a>`: same site-wide `.btn,button,input[type=
    // submit]{border-radius:8px!important;padding:4px 4px
    // !important;border:none!important}` override as every other
    // `.btn` in the app (Round 36) — `.undo-btn`'s own `padding:
    // 7px 15px!important` loses to it (same specificity, later
    // load order). `.btn-primary,.btn-purple,.btn-default{
    // background:var(--primary-color)!important;color:white
    // !important}` confirms the fill/icon color. Icon itself
    // measured 14x14 (not this screen's previous 20px), and the
    // real `.btn{line-height:21px}` (unopposed) plus the 4px
    // padding gives the whole button a real ~22x29 footprint —
    // not a flat 44x44 box. Was previously radius 10 with no
    // real-CSS basis and a much larger box/icon.
    // Per a real mobile screenshot: on phone this button sits BELOW
    // the search field (not beside it) and is a full circle, not the
    // desktop's rounded-square — same fill/icon otherwise.
    final resetButton = HoverBuilder(
      cursor: offline ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder:
          (context, hovering) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.translationValues(
              0,
              hovering && !offline ? -1 : 0,
              0,
            ),
            decoration: BoxDecoration(
              boxShadow:
                  hovering && !offline
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
              color:
                  offline
                      ? _muted.withValues(alpha: 0.4)
                      : (hovering ? FigmaTokens.purpleHover : _purple),
              shape: isTablet ? null : const CircleBorder(),
              borderRadius: isTablet ? BorderRadius.circular(8) : null,
              child: InkWell(
                onTap: offline ? null : widget.onReset,
                customBorder: isTablet ? null : const CircleBorder(),
                borderRadius: isTablet ? BorderRadius.circular(8) : null,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: SizedBox(
                    width: 14,
                    height: 21,
                    child: Icon(
                      Icons.undo_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child:
          isTablet
              ? Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 8),
                  resetButton,
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  searchField,
                  const SizedBox(height: 10),
                  resetButton,
                ],
              ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.onRetry});
  final LearningPathsState state;
  final VoidCallback onRetry;

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
            'Unable to load learning paths.',
          ),
          onRetry: onRetry,
        );
      case DataProviderState.data:
        if (state.paths.isEmpty) return const _EmptyState();
        final total = state.paths.length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // CSS ref, confirmed via a live devtools cascade dump on the
            // real `.structure-block` wrapping this table: `background:
            // var(--white);padding:20px;border:1px solid #E7E4FF;
            // border-radius:16px` — no box-shadow at all (was an
            // invented `0 6px 16px rgba(0,0,0,.04)`, radius 14). Same
            // real class every other My Courses screen's white card
            // already uses (see Round 40/Required Courses).
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE7E4FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Builder(
                      builder: (context) {
                        final isTablet = Responsive.isTablet(context);
                        // CSS ref, confirmed via a live devtools cascade
                        // dump on the real `.structure-block h1`: 24px/
                        // w400/line-height:28, color var(--primary-
                        // second)=#A20067 (site-wide h1 rule also gives
                        // it Inter via `font-family:var(--primary-font)
                        // !important`) — was wrongly 20px/w800/#B0006D
                        // with no font-family set at all. Per explicit
                        // request, sized down further on phone (18, was
                        // the same 24 as tablet) to match a real mobile
                        // screenshot.
                        final title = Text(
                          'Learning Paths',
                          style: GoogleFonts.inter(
                            color: _sectionTitle,
                            fontSize: isTablet ? 24 : 18,
                            fontWeight: FontWeight.w400,
                            height: 28 / 24,
                          ),
                        );
                        final subtitle = RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: _muted,
                              fontSize: isTablet ? 12.5 : 11,
                            ),
                            children: [
                              const TextSpan(text: 'Showing '),
                              TextSpan(
                                text: '1-$total',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              const TextSpan(text: ' of '),
                              TextSpan(
                                text: '$total',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              const TextSpan(text: ' items.'),
                            ],
                          ),
                        );
                        // Per a real mobile screenshot: title and
                        // subtitle stack (both left-aligned), not the
                        // desktop's same-line `spaceBetween` Row — with
                        // a bit more breathing room between them than a
                        // bare stack gives (per explicit request).
                        return isTablet
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [title, subtitle],
                            )
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title,
                                const SizedBox(height: 6),
                                subtitle,
                              ],
                            );
                      },
                    ),
                  ),
                  _PathsTable(paths: state.paths),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const AppFooter(),
          ],
        );
    }
  }
}

// ─── Paths table ──────────────────────────────────────────────────────────────

/// Owns which rows are expanded so the header's +/- can expand or collapse
/// every row at once, alongside each row's own individual toggle.
class _PathsTable extends StatefulWidget {
  const _PathsTable({required this.paths});
  final List<LearningPath> paths;

  @override
  State<_PathsTable> createState() => _PathsTableState();
}

class _PathsTableState extends State<_PathsTable> {
  final Set<int> _expanded = {};

  bool get _allExpanded =>
      widget.paths.isNotEmpty && _expanded.length == widget.paths.length;

  void _toggleAll() {
    setState(() {
      if (_allExpanded) {
        _expanded.clear();
      } else {
        _expanded
          ..clear()
          ..addAll(List.generate(widget.paths.length, (i) => i));
      }
    });
  }

  void _toggleRow(int index) {
    setState(() {
      if (_expanded.contains(index)) {
        _expanded.remove(index);
      } else {
        _expanded.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Per a real mobile screenshot: there's no header row at all on
    // phone (no "Learning Path"/"Group" labels, no expand-all — the
    // real page just goes straight from the "Showing X of Y items."
    // line to the first data row).
    final isTablet = Responsive.isTablet(context);
    return Column(
      children: [
        if (isTablet) ...[
          _TableHeaderRow(allExpanded: _allExpanded, onToggleAll: _toggleAll),
          const Divider(height: 1, color: Color(0xFFDBE5E9)),
        ],
        for (var i = 0; i < widget.paths.length; i++) ...[
          _PathRow(
            index: i + 1,
            path: widget.paths[i],
            expanded: _expanded.contains(i),
            onToggle: () => _toggleRow(i),
          ),
          if (i != widget.paths.length - 1)
            const Divider(height: 1, color: Color(0xFFDBE5E9)),
        ],
      ],
    );
  }
}

// ─── Table header row ───────────────────────────────────────────────────────

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow({required this.allExpanded, required this.onToggleAll});
  final bool allExpanded;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    // CSS ref, confirmed via a live devtools cascade dump on the real
    // `<thead class="kv-table-header">`: `.kv-table-header{background:
    // linear-gradient(to bottom,#fff 0%,#eee 100%)}` genuinely WINS
    // (beats `.kv-table-header,.kv-table-footer{background:#fff}`,
    // which loses) — a previous round wrongly called this gradient
    // "invented, no CSS backing" and removed it; the live cascade says
    // otherwise. `.table-bordered > thead.kv-table-header > tr, ...,
    // .kv-table-header > tr > th, .kv-table-header > tr > td{border-
    // bottom:none;border-top:none}` confirms the header itself has NO
    // border of its own — the visible divider line below it is the
    // separate `Divider` `_PathsTable` already renders right after
    // this row, not this Container's own border (which was redundant
    // with it before this fix). Column labels/text style otherwise
    // unchanged: base `.table th` override (weight 400, 16px/lh20,
    // color var(--primary-first)). Padding corrected from an earlier
    // `padding:15px` reading: a live cascade dump on the actual tbody
    // `<td class="kv-expand-icon-cell">` shows `.table th, .table
    // td{padding:0.75rem}` (12px) WINNING outright — it also beats
    // `.kv-expand-header-cell, .kv-expand-icon-cell{padding-top:0;
    // padding-bottom:0}` on specificity (compound class+element
    // selector beats the single-class one), so there's no special-
    // cased zero-vertical-padding for the expand cell either; 12px
    // uniform is the real value for every `.table th`/`.table td`.
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFEEEEEE)],
        ),
      ),
      child: Row(
        children: [
          // CSS ref: the expand column's real markup is a plain
          // `<span class="fa fa-plus-square">`/`fa-minus-square` styled
          // `color: var(--primary-first)` — a single monochrome glyph,
          // not a separate background chip. The "filled square with a
          // white plus" look in the real screenshot is the glyph's own
          // vector shape (the plus/minus is a cut-out hole in the icon
          // path, not a second color) — that's Material's FILLED
          // `add_box`/`indeterminate_check_box`, not the `_outlined`
          // variants (hollow border, no fill) previously used here.
          // Size corrected 20→16: this header `<th>` is 49.85×44.8
          // (matches the 12px padding already applied) wrapping a
          // 25.85×20 icon div whose `.fa` glyph measures 14×16 — that's
          // the inherited `.table th{font-size:16px}` context, not the
          // losing `.kv-expand-header-cell{font-size:1.35em}` override.
          InkWell(
            onTap: onToggleAll,
            child: Icon(
              allExpanded ? Icons.indeterminate_check_box : Icons.add_box,
              color: _purple,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          // CSS ref: the real `<colgroup>` has a 4th, blank-labelled
          // column (`<th data-col-seq="1" style="width:11.97%">`, no
          // text — it's the row's own serial-number "#" cell) sitting
          // BETWEEN the expand icon and "Learning Path"; widths for
          // seq 1/2/3 are 11.97% / 61.42% / 23.2%. `_pathNameLine`
          // used to run the "1."/"2." index right up against the name
          // text with only an 8px gap — this spacer reproduces the
          // real gap instead, and the flex ratios below (12:61:23)
          // match those measured widths so this header and the data
          // rows' columns line up. This whole widget is only ever
          // rendered on tablet+ now — the real page has no header row
          // at all on phone (see `_PathsTableState.build`).
          const Expanded(flex: 12, child: SizedBox.shrink()),
          Expanded(
            flex: 61,
            child: Text(
              'Learning Path',
              style: GoogleFonts.inter(
                color: _purple,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 20 / 16,
              ),
            ),
          ),
          Expanded(
            flex: 23,
            child: Text(
              'Group',
              style: GoogleFonts.inter(
                color: _purple,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 20 / 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Learning path row ────────────────────────────────────────────────────────

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.index,
    required this.path,
    required this.expanded,
    required this.onToggle,
  });
  final int index;
  final LearningPath path;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    // CSS ref: `.table th, .table td{padding:0.75rem}` (12px) — corrected
    // from an earlier `padding:15px` reading; a live cascade dump on the
    // real tbody `<td>` showed 0.75rem winning outright (see
    // `_TableHeaderRow` for the full specificity note). Row separator is
    // the base Bootstrap `.table td` top border (~#DBE5E9, matching the
    // header's overridden border-color) — not shown here since it's drawn
    // by the `Divider` the parent `_PathsTable` already places between
    // rows.
    final isTablet = Responsive.isTablet(context);
    // CSS ref: same `fa-plus-square`/`fa-minus-square` glyph as the
    // header toggle — see `_TableHeaderRow` for the full note on why
    // this is the FILLED Material icon (the glyph's own cut-out plus/
    // minus, not a real background chip) at 16px, not the `_outlined`
    // variant at 20px.
    final icon = Padding(
      padding: const EdgeInsets.only(top: 2),
      child: InkWell(
        onTap: onToggle,
        child: Icon(
          expanded ? Icons.indeterminate_check_box : Icons.add_box,
          color: _purple,
          size: 16,
        ),
      ),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Per a real mobile screenshot: the toggle icon sits at
              // the END of the row on phone (trailing), not the start
              // — the opposite of the tablet/desktop layout confirmed
              // earlier. Only shown leading here on tablet+.
              if (isTablet) ...[icon, const SizedBox(width: 10)],
              Expanded(
                child:
                    isTablet
                        ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // CSS ref: same real `<colgroup>` as
                            // `_TableHeaderRow` — a blank-labelled
                            // serial-number column (11.97%) sits
                            // between the expand icon and the
                            // "Learning Path" name column (61.42%),
                            // with "Group" at 23.2%; flex 12:61:23
                            // matches. Was the index digit run right
                            // up against the name with only an 8px
                            // gap, inside the same flex:6 column as
                            // the name.
                            // Per explicit request: this index digit is
                            // purple, not plain body text.
                            Expanded(
                              flex: 12,
                              child: Text(
                                '$index.',
                                style: GoogleFonts.inter(
                                  color: _purple,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 61,
                              child: Text(
                                path.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: _ink,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 15,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 23,
                              child:
                                  path.groupName.isEmpty
                                      ? const SizedBox.shrink()
                                      : Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          path.groupName,
                                          style: GoogleFonts.inter(
                                            color: _ink,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                            ),
                          ],
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _pathNameLine(index),
                            if (path.groupName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                path.groupName,
                                style: GoogleFonts.inter(
                                  color: _ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
              ),
              if (!isTablet) ...[const SizedBox(width: 10), icon],
            ],
          ),
        ),
        if (expanded)
          Padding(
            // Tablet: left-aligned with the path name text above (row
            // padding 12 + the 20px expand icon + the 10px gap after
            // it). Phone: the icon moved to the trailing edge (see
            // above), so the content starts right after the row's own
            // 12px padding, with no extra icon-width offset needed.
            padding:
                isTablet
                    ? const EdgeInsets.fromLTRB(42, 0, 12, 12)
                    : const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _CompetencyPreview(path: path),
          ),
      ],
    );
  }

  // CSS ref: the "Learning Path" data column is plain `attribute =>
  // 'learningPath.name'` — no value/format override — so it inherits
  // default `.table td` body-text styling, not the purple/bold treatment
  // reserved for `.table th` headers. Row number is `++$index . '.'`
  // rendered inline with it — per explicit request this index digit is
  // purple, while the name text stays plain body color. Used only for
  // the phone-stacked layout — the tablet layout renders the index in
  // its own real-column-matching `Expanded` instead (see `build` above).
  Widget _pathNameLine(int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$index.',
          style: GoogleFonts.inter(
            color: _purple,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            path.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: _ink,
              fontWeight: FontWeight.w400,
              fontSize: 15,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompetencyPreview extends StatelessWidget {
  const _CompetencyPreview({required this.path});
  final LearningPath path;

  @override
  Widget build(BuildContext context) {
    final competencies = path.competencies;
    if (competencies.isEmpty) {
      return Text(
        path.courses.isEmpty
            ? 'No competency details available.'
            : 'Courses: ${path.courses.map((c) => c.name).join(', ')}',
        style: const TextStyle(color: _ink, fontSize: 12.5, height: 1.4),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phone: rows below stack these fields instead of a 4-column table,
        // so the column header row doesn't apply.
        // CSS ref: same `.table th` rule (plain purple text, weight 400,
        // 16px/lh20 — was 700/12.5) applies to this nested grid too, since
        // it's still a plain kartik `GridView` with no extra column
        // styling of its own. Vertical padding corrected 8→12 to match
        // the confirmed `.table th, .table td{padding:0.75rem}` (12px),
        // same live-cascade evidence as the outer Learning Paths table.
        if (Responsive.isTablet(context)) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Competency',
                    style: TextStyle(
                      color: _purple,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 20 / 16,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Courses',
                    style: TextStyle(
                      color: _purple,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 20 / 16,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Competency Type',
                    style: TextStyle(
                      color: _purple,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 20 / 16,
                    ),
                  ),
                ),
                SizedBox(width: 90),
              ],
            ),
          ),
          // CSS ref: this nested table's own `.table thead th{border-
          // bottom:2px solid #dee2e6}` genuinely wins (confirmed live —
          // beats a losing `.table thead th{border-bottom:1px solid
          // #DBE5E9}`) — plain Bootstrap default color/width here, not
          // the site override used elsewhere (that #DBE5E9/1px value
          // belongs to a different, unrelated `.table thead th` rule
          // that loses in this specific cascade).
          const Divider(height: 2, thickness: 2, color: Color(0xFFDEE2E6)),
        ],
        for (var i = 0; i < competencies.length; i++) ...[
          _CompetencyPreviewRow(
            index: i + 1,
            pathId: path.id,
            competency: competencies[i],
          ),
          // Phone: each row is its own pale-blue rounded card with its
          // own margin (see `_CompetencyPreviewRow`) — a divider line
          // between them isn't needed there and looks wrong sitting in
          // the gap.
          if (Responsive.isTablet(context) && i != competencies.length - 1)
            const Divider(height: 1, color: Color(0xFFDBE5E9)),
        ],
      ],
    );
  }
}

class _CompetencyPreviewRow extends StatelessWidget {
  const _CompetencyPreviewRow({
    required this.index,
    required this.pathId,
    required this.competency,
  });
  final int index;
  final int pathId;
  final LearningPathCompetency competency;

  Widget _viewButton(BuildContext context) {
    if (competency.name.isEmpty) return const SizedBox.shrink();
    final isTablet = Responsive.isTablet(context);
    return HoverBuilder(
      builder: (context, hovering) {
        void onPressed() => _openViewCompetency(
          context,
          learningPathId: pathId,
          competency: competency.name,
        );
        // CSS ref: default state is a plain purple icon+text link, no
        // border/box — confirmed via a screenshot of the real button
        // (the site-wide `.btn,button,...{border:none!important}`
        // override nulls out `.btn-outline-primary`'s own `border-
        // color`, a `!important` shorthand beats a longhand regardless
        // of which "wins" the cascade). A SECOND screenshot, of the
        // real `:hover` state, shows it genuinely does fill solid
        // purple with white icon/text on hover — so that half of the
        // earlier two-state button (before it was wrongly collapsed
        // into one borderless `TextButton` for both states) was
        // right after all; only the default state's border was the
        // bug. Restored as a real two-state button. Icon switched from
        // `remove_red_eye_outlined` to the filled `remove_red_eye` —
        // real markup's `<i class="fa fa-eye">` is the solid glyph.
        final shape = const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        );
        // Per explicit request: sized down further on phone (12, was
        // the same 14 as tablet) to match a real mobile screenshot.
        final textStyle = TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: isTablet ? 14 : 12,
        );
        final iconSize = isTablet ? 14.0 : 12.0;
        const padding = EdgeInsets.all(4);
        return hovering
            ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(
                Icons.remove_red_eye,
                size: iconSize,
                color: Colors.white,
              ),
              label: const Text('View'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
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
              icon: Icon(Icons.remove_red_eye, size: iconSize),
              label: const Text('View'),
              style: TextButton.styleFrom(
                foregroundColor: _purple,
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

  @override
  Widget build(BuildContext context) {
    final courses = competency.courseNames;
    // CSS ref: `yii\grid\SerialColumn`'s content has no color override
    // either — plain body text (was purple/600).
    final competencyName = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$index', style: const TextStyle(color: _ink, fontSize: 12.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            competency.name.isEmpty ? '—' : competency.name,
            style: const TextStyle(color: _ink, fontSize: 12.5),
          ),
        ),
      ],
    );

    if (!Responsive.isTablet(context)) {
      // Design call, built from a real mobile screenshot (no devtools
      // evidence given): each competency on phone is its own pale-blue
      // rounded card with bold black "Label:" text followed by a blue
      // value — not the plain stacked/unstyled text the tablet-width
      // fallback below uses. "Courses:"/"Type:" labels are shown even
      // when the value is empty (the real screenshot's first card has
      // a bare "Courses:" with nothing after it).
      // Per explicit request: label weight eased 700→600, value size
      // eased 13.6→12.5.
      const labelStyle = TextStyle(
        color: _ink,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      );
      // CSS ref, confirmed via the computed-style inspector on the
      // real "Type: AND" cell: `color:#808B96; font:13.6px Inter` —
      // was an invented sky-blue `#2B6CB0` with no CSS backing.
      // `fontWeight` explicitly set to normal — without it, the value
      // span was inheriting the label span's bold weight (`RichText`
      // merges an unset child style with its parent's), which is why
      // "Development"/"AND" rendered bold like their labels instead of
      // the real page's lighter weight.
      const valueStyle = TextStyle(
        color: Color(0xFF808B96),
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
      );
      // CSS ref, confirmed via the computed-style inspector on the
      // real cells: "Competency:" value is `#5B62A5`, "Courses:" value
      // is `#2C3E50` — distinct per-field colors, not the single grey
      // `valueStyle` above (kept only for "Type:", which neither
      // screenshot covered).
      const competencyValueStyle = TextStyle(
        color: Color(0xFF5B62A5),
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
      );
      const coursesValueStyle = TextStyle(
        color: Color(0xFF2C3E50),
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
      );
      // CSS ref, confirmed via the computed-style inspector on the
      // real `<tr>`: `background:#EBF9FA` (was an invented `#DCEEF5`),
      // `padding:15px 7px 7px 40px`. The real index number sits in
      // that 40px left gutter, outside the padded content — everything
      // else ("Competency:"/"Courses:"/"Type:"/"View") starts at that
      // same 40px inset regardless of line. Previously "Courses:" and
      // "Type:" were separate `Column` children sitting at the card's
      // left edge (under the index digit, not under "Competency:") —
      // per explicit request, moved inside the same `Expanded` as
      // "Competency:" so every line shares one consistent left edge.
      // The 40px inset is reproduced as 12px container padding + a
      // 28px index column, rather than literally padding the whole
      // container 40px on the left (which would also indent the index
      // itself, undoing the gutter effect).
      return Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.fromLTRB(12, 15, 7, 7),
        decoration: BoxDecoration(
          color: const Color(0xFFEBF9FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 28, child: Text('$index', style: labelStyle)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: labelStyle,
                      children: [
                        const TextSpan(text: 'Competency: '),
                        TextSpan(
                          text: competency.name.isEmpty ? '—' : competency.name,
                          style: competencyValueStyle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(
                      style: labelStyle,
                      children: [
                        const TextSpan(text: 'Courses: '),
                        TextSpan(
                          text: courses.join(', '),
                          style: coursesValueStyle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(
                      style: labelStyle,
                      children: [
                        const TextSpan(text: 'Type: '),
                        TextSpan(
                          text: competency.competencyType.toUpperCase(),
                          style: valueStyle,
                        ),
                      ],
                    ),
                  ),
                  if (competency.name.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Center(child: _viewButton(context)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // CSS ref: `.table td{padding:0.75rem}` (12px) confirmed live for
    // this table's body rows too, same rule as the header — was 10.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: competencyName),
          Expanded(
            flex: 4,
            child: Text(
              courses.join(', '),
              style: const TextStyle(color: _ink, fontSize: 12.5),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              competency.competencyType.toUpperCase(),
              style: const TextStyle(color: _ink, fontSize: 12.5),
            ),
          ),
          SizedBox(
            width: 90,
            child: Align(
              alignment: Alignment.centerRight,
              child: _viewButton(context),
            ),
          ),
        ],
      ),
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
                Icons.account_tree_outlined,
                color: _purple,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Learning Paths',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Learning paths available to you will appear here.',
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

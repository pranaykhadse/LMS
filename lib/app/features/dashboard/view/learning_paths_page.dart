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
    // CSS ref: real `div.container` on this page — `width:100%; margin:auto`
    // but padding changes with breakpoint:
    // `@media (max-width:640px){.container{padding:5px !important}}` and
    // `@media (max-width:991.98px){.container{padding-left:15px !important;
    // padding-right:15px !important; max-width:100% !important}}`.
    // At iPhone SE (375px) the live box model shows 5px on all sides
    // (365.2 content inside 375.2 outer). Reproduce that here so the
    // search block and structure-block sit inside the same container
    // inset as the web page.
    //
    // Above 991.98px that override no longer applies, so it's Bootstrap's
    // base `.container` rule instead — `padding` is commented out there
    // (confirmed against `origin/staging`'s `app.css`), but that rule ALSO
    // caps `max-width` (960px at >=992px, 1140px at >=1200px) and centers
    // via `margin:auto`. A prior pass read only the padding half of that
    // rule and rendered this page full-bleed on desktop — a live
    // screenshot shows the real page has a clear side margin there, which
    // is that max-width capping + centering, not padding. Reproduced with
    // `Center`+`ConstrainedBox` instead of literal padding, since the
    // margin here comes from the container not spanning the full width in
    // the first place.
    final w = MediaQuery.sizeOf(context).width;
    final EdgeInsets containerPadding;
    double? containerMaxWidth;
    if (w <= 640) {
      containerPadding = const EdgeInsets.all(5);
    } else if (w <= 991.98) {
      containerPadding = const EdgeInsets.symmetric(horizontal: 15);
    } else {
      containerPadding = EdgeInsets.zero;
      containerMaxWidth = w >= 1200 ? 1140 : 960;
    }

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
      body: Padding(
        padding: containerPadding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: containerMaxWidth ?? double.infinity,
            ),
            child: Column(
              children: [
                _SearchBar(
                  controller: _searchController,
                  onSearch: _onSearch,
                  onReset: _onReset,
                ),
                Expanded(
                  child: _Body(state: state, onRetry: () => notifier.fetch()),
                ),
              ],
            ),
          ),
        ),
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

    // CSS ref — mobile inspection on iPhone SE (375×667):
    // `div.search-blcok` margin 0 0 15 at ≤767; `div.row` flex-wrap;
    // `.col-*` padding 15 each side; `.form-group` margin-bottom 1rem (16);
    // `input.searchInput.form-control.pl-5` height 42, `pl-5{padding-left:
    // 3rem !important}` (48), `:where(input[type=text],...)` wins with
    // `background:var(--bg-white) #FFFFFF`, `border:1px solid
    // var(--border-light) #E2E8F0`, `border-radius:8px !important`,
    // `padding:10px 12px`, `font:14px Roboto`, `color:#2D3748`,
    // `height:42` from `.form-control`; `.search i` absolute `left:10
    // top:12 color:#693D94 font-size:20`. Box model at 375px:
    // container 5 → search-blcok 365.2×87 → row 365.2×87 →
    // col-lg-11 365.2×58 (content 335.2+15+15, 42+16) → input
    // 335.2×42 with icon 20×20 inside. Applied below.
    final searchField = Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: SizedBox(
        height: 42,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
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
              style: GoogleFonts.roboto(
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
                hintStyle: GoogleFonts.roboto(
                  color: const Color(0xFF6C757D),
                  fontSize: 15,
                  letterSpacing: 1.0,
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.fromLTRB(10, 12, 0, 12),
                  child: Icon(Icons.search, color: Color(0xFF693D94), size: 20),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 30,
                  minHeight: 20,
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
                fillColor: Colors.white,
                hoverColor: Colors.transparent,
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(48, 10, 12, 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _purple, width: 1.5),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _inputBorder),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // CSS ref, iPhone SE (375px) on `a.btn.btn-primary.undo-btn`
    // wrapping `i.fa.fa-undo` (352857):
    // `.col-* {padding-left/right:15}` positions the column; its content
    // box is `335.2` inside `365.2` (container 5 + row flex-wrap `365.2×29`
    // for this column, `365.2×58` for the input column above).
    // This link itself box is `21×29` with `335.2×29` column content
    // (padding 4 on all sides → `13×21` content). Winning rules:
    // `.btn,button,...{border-radius:8px!important;padding:4px 4px!important;
    // border:none!important;font:600 14px Roboto;line-height:21px}` +
    // `.btn-primary{background:var(--primary-color)#693D94;color:white!important}`
    // beat `.undo-btn{padding:7px 15px}`; at `≤991.98` `padding:4px 6px`,
    // at `≤768` `width:100%;padding:4px`, at `≤767` `width:auto;padding:6px 12px`,
    // at `≤480` `padding:4px` — at 375 the cascade resolves to `4px`
    // all sides, `radius:8`, `weight:600`, `size:14`, `auto` width.
    // `i.fa-undo` itself is `13×13` (`::before 13×12.8`), `font-weight:900`.
    // Not a circle — plain rounded `8px` rectangle, stacked below the
    // input (`form-group` margin `1rem/16` separates them), left-aligned
    // inside its `15px` padded column.
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
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: offline ? null : widget.onReset,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: SizedBox(
                    width: 13,
                    height: 21,
                    child: Icon(
                      Icons.undo_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
    );

    // CSS ref: real `.search-blcok` — `@media (max-width:767px){
    // .search-blcok{margin:0 0 15px 0}}`. At iPhone SE (375px) the
    // box model shows 365.2×87 content inside the 5px container padding,
    // with a 15px bottom margin separating it from the structure-block
    // below. Inside: `div.row{flex-wrap:wrap}` with
    // `.col-* {padding-left/right:15px; width:100%}` and `.form-group
    // {margin-bottom:1rem (16)}`. On phone both search cols are
    // `col-12` (100% stacked): col-lg-11 holds the 335.2×42 input with
    // 16 bottom margin (58 total), col-lg-1 holds the reset button
    // below it, row totals 87 (58+29). Reproduce with symmetric 15
    // insets and 16 gap.
    final w2 = MediaQuery.sizeOf(context).width;
    final isSearchPhone = w2 <= 767;
    // Exact: `.search-blcok` only has `margin:0 0 15px 0` at `≤767`; no
    // top/bottom on desktop. Gap to structure-block is via
    // `structure-block{margin:30px 0 10px}` desktop vs `0 0 10` phone.
    final EdgeInsets searchOuter;
    if (isSearchPhone) {
      searchOuter = const EdgeInsets.only(bottom: 15);
    } else {
      searchOuter = EdgeInsets.zero;
    }
    if (isTablet) {
      return Padding(
        padding: searchOuter,
        child: Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 8),
            resetButton,
          ],
        ),
      );
    }
    // Phone: Row flex-wrap → stacked col-12's, each with 15 side padding;
    // form-group margin-bottom 16 between input and button row.
    return Padding(
      padding: searchOuter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: searchField,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Align(alignment: Alignment.centerLeft, child: resetButton),
          ),
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
        // Outer `div.container` (5px at ≤640px, 15px horiz at ≤991.98px)
        // now provides the outer inset, the `.row` is `display:flex;
        // flex-wrap:wrap` and each `.col-*` has `padding-left/right:15px;
        // width:100%; max-width:100%; flex:0 0 100%`. For the structure
        // block this is `div.row > div.col-lg-12.col-md-12.col-12` (15
        // each side) wrapping `div.structure-block`. The old 16/16/16/24
        // here double-counted (search bottom 14 + list top 16 =30px plus
        // 16 horiz on top of container's 5/15). On phone iPhone SE the
        // combined inset is container 5 + col 15 =20 each side (col 15
        // applied here).
        // CSS ref for structure-block: base
        // `background:var(--white);padding:20px;margin:30px 0 10px;
        // border:1px solid #E7E4FF;border-radius:16px`; at `≤767`
        // `margin:0 0 10px` and `.structure-block>div{flex-direction:column}`
        // + `.table-responsive{overflow-x:visible}` and
        // `.float-right{order:-1;margin-bottom:15px;font-size:0.85rem;
        // color:#6c757d}`; at `≤640` `padding:15px`; `h1{24px/28 Roboto
        // #A20067}` at `≤767` `{order:-2;font-size:1.5rem(24);margin:10px 0 5px}`;
        // `.clearfix{display:none}`; parent row `365.2×304.4` → col
        // `365.2×304.4` (15 pad → 335.2) → structure-block `335.2×294.4`
        // (15 pad → 303.6 content, 10 bottom margin).
        final w3 = MediaQuery.sizeOf(context).width;
        final isListPhone = w3 <= 767;
        final isCompact = w3 <= 640;
        return ListView(
          padding: EdgeInsets.fromLTRB(0, 0, 0, isListPhone ? 12 : 16),
          children: [
            // `div.row (365.2×304.4) > div.col-12 (15 pad)` already via
            // the Padding below; `div.structure-block` itself:
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isListPhone ? 15 : 0),
              child: Container(
                // `≤640:15px` else `20px` per `.structure-block` media;
                // `margin:30px 0 10px` desktop vs `0 0 10px` at `≤767`.
                padding: EdgeInsets.all(isCompact ? 15 : 20),
                margin: EdgeInsets.only(top: isListPhone ? 0 : 30, bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE7E4FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mobile: `.structure-block>div{flex-direction:column}` +
                    // `.structure-block h1{order:-2;font-size:1.5rem(24);margin:10px 0 5px}`
                    // + `.float-right{order:-1;margin-bottom:15px;font-size:0.85rem(13.6);
                    // color:#6c757d}` + `.clearfix{display:none}` + overflow visible.
                    // At iPhone SE the visible header is h1 `303.6×28`
                    // (15 pad → 303.6 content) and summary `303.6×20.4` (0.85rem)
                    // below it, then the table `303.6×262.8`.
                    Padding(
                      padding: EdgeInsets.only(bottom: isListPhone ? 0 : 12),
                      child: Builder(
                        builder: (context) {
                          final isTablet = Responsive.isTablet(context);
                          // CSS ref, confirmed via a live devtools cascade
                          // dump on the real `.structure-block h1`: 24px/
                          // w400/line-height:28, color var(--primary-
                          // second)=#A20067; at `≤767` `{order:-2;
                          // font-size:1.5rem(24);margin-top:10px;
                          // margin-bottom:5px}`. Previously reduced to 18
                          // on phone per screenshot request — now aligned
                          // to the inspected `1.5rem` per latest dump.
                          final title = Padding(
                            padding: EdgeInsets.only(
                              top: isListPhone ? 10 : 0,
                              bottom: isListPhone ? 5 : 0,
                            ),
                            child: Text(
                              'Learning Paths',
                              style: GoogleFonts.roboto(
                                color: _sectionTitle,
                                fontSize: 24,
                                fontWeight: FontWeight.w400,
                                height: 28 / 24,
                              ),
                            ),
                          );
                          final subtitle = Padding(
                            padding: EdgeInsets.only(
                              bottom: isListPhone ? 15 : 0,
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color:
                                      isListPhone
                                          ? const Color(0xFF6C757D)
                                          : _muted,
                                  fontSize: isListPhone ? 13.6 : 12.5,
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
                            ),
                          );
                          // Per a real mobile screenshot: title and
                          // subtitle stack (both left-aligned), not the
                          // desktop's same-line `spaceBetween` Row.
                          // On phone the `h1` margin `5 bottom` plus the
                          // summary's own `0` top provides the gap; the
                          // previous `6px` request is covered by the `h1`
                          // `10/5` + summary `15 bottom` inspected.
                          return isTablet
                              ? Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [title, subtitle],
                              )
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [title, subtitle],
                              );
                        },
                      ),
                    ),
                    _PathsTable(paths: state.paths),
                  ],
                ),
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
// CSS ref, iPhone SE (375px) — latest batch:
// `.table-responsive{display:block;width:100%;overflow-x:auto}` vs
// `@767 {overflow-x:visible !important}` (so phone grid is NOT
// horizontally scrollable) + `.table{width:100%;margin-bottom:1rem;
// color:#212529}` overridden by `.table{margin-bottom:0!important}`
// (no bottom gap) + `col/colgroup` are `display:table-column(*)`
// with `colgroup` widths driven by kartik `col` widths (skip-export
// `309.08×622.8` etc) but collapsed to `0×0` on phone for the hidden
// expand-icon/number columns; visible `303.6×262.8` (`w0`) inside
// `335.2×294.4` structure-block → `303.6×184.4` grid-container →
// `309.08×184.4` table → `col 309.08×622.8` reflects the stacked
// card height on phone. Flutter replicates as non-scrollable
// `Column` of `_PathRow` cards with no header on phone, no
// horizontal scroll, and `303.6` content width via the
// container5 + col15 + structure15 + border0.8 chain above.

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
              style: GoogleFonts.roboto(
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
              style: GoogleFonts.roboto(
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
    // Pixel-perfect expand icon — inspected iPhone SE (375):
    // `td:first-child` `24.5×42` (`width:50px` desktop, absolute
    // `right15 top50% translateY-50% width:auto` at ≤767) containing
    // `div.kv-expand-row 24.5×42` → `div.kv-expand-icon 24.5×42` →
    // `span.fa.fa-plus-square` `24.5×28` (`::before 24.5×28`) `color:
    // var(--primary-first)#693D94` `font:900 14px/1 FA`. Tablet
    // keeps previous `16` to match `12px` th padding; phone uses the
    // inspected `24.5×28` bounding box. No top padding offset — the
    // `42` cell is vertically centered via `top50%` already.
    final icon = InkWell(
      onTap: onToggle,
      child: Icon(
        expanded ? Icons.indeterminate_check_box : Icons.add_box,
        color: _purple,
        size: isTablet ? 16 : 24.5,
      ),
    );
    // Phone vs tablet branching per latest batch:
    // `@767 .table tbody tr{display:block;position:relative;border:1px solid #c5c5c5;
    // radius:8;margin-bottom:15;background:#fff;padding:15px 60px 15px 40px}`
    // + `@640 {display:flex;align-items:center;justify-content:center;
    // border:1px solid #F3F4F6!important}` (at 375 flex wins, border #F3F4F6).
    // `@767 td:first-child{position:absolute;right15;top50%;translateY-50%;width:auto}`
    // (expand icon `24.5×42` cell, `24.5×28` icon) +
    // `td:nth-child(2){position:absolute;left15;top15;color:#5b62a5}` (number)
    // + `td:nth-child(3){display:block;width:100%;font-weight:400;color:#2c3e50}`
    // (name) + `td:nth-child(4){font-size:0.85rem(13.6);color:#808b96;margin-top:5}`
    // (group) + `td{display:block;border:none;padding:0;text-align:left}`
    // + `.number{font:400 16px/19 #693D94}` (overridden by #5b62a5 at phone) +
    // `tr 309.08×77.2` inside `303.6` table. Tablet keeps the 12px flex row.
    final isCompact640 = MediaQuery.sizeOf(context).width <= 640;
    if (isTablet) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 12,
                        child: Text(
                          '$index.',
                          // CSS ref `.number`: font:400 16px/19,
                          // color var(--primary-first) (was 15px).
                          style: GoogleFonts.roboto(
                            color: _purple,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 19 / 16,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 61,
                        child: Text(
                          path.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          // CSS ref: the plain `attribute =>
                          // 'learningPath.name'` cell has no size override —
                          // inherits body 14px (was 15px).
                          style: GoogleFonts.roboto(
                            color: _ink,
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            height: 1.5,
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
                                    // Same 14px body inheritance as the name
                                    // cell (was 15px).
                                    style: GoogleFonts.roboto(
                                      color: _ink,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(42, 0, 12, 12),
              child: _CompetencyPreview(path: path),
            ),
        ],
      );
    }
    // Phone: card `block` (flex at ≤640 centered) `309.08×77.2` with
    // `40` left / `60` right reservation for absolute number/icon.
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color:
                  isCompact640
                      ? const Color(0xFFF3F4F6)
                      : const Color(0xFFC5C5C5),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          // `padding:15 60 15 40` from tr spec — implemented via Stack
          // with centered content. At ≤640 `display:flex;center` so
          // content is centered.
          child: Stack(
            children: [
              // Centered name/group column (width 100% per nth-child(3))
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 15, 60, 15),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        path.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          color: const Color(0xFF2C3E50),
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      if (path.groupName.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          path.groupName,
                          style: GoogleFonts.roboto(
                            color: const Color(0xFF808B96),
                            fontSize: 13.6,
                            fontWeight: FontWeight.w400,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Number `1.` at `left15 top15` `#5b62a5` (overrides `.number #693D94`)
              Positioned(
                left: 15,
                top: 15,
                child: Text(
                  '$index.',
                  style: GoogleFonts.roboto(
                    color: const Color(0xFF5B62A5),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 19 / 16,
                  ),
                ),
              ),
              // Expand icon at `right15` centered vertically `24.5×42`
              Positioned(
                right: 15,
                top: 0,
                bottom: 0,
                child: Center(
                  child: SizedBox(
                    width: 24.5,
                    height: 42,
                    child: Center(child: icon),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (expanded)
          Padding(
            // The phone cards carry their own 15px margins (web
            // `.kv-detail-content .table tbody tr{margin:15px}`), so this
            // wrapper just leaves the top breathing room.
            padding: const EdgeInsets.only(top: 12),
            child: _CompetencyPreview(path: path),
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
    // either — plain body text (was purple/600). Phone index styling —
    // `.kv-detail-content .table tbody td:first-child` at `≤767`:
    // `position:absolute; left:20px; top:26px; font-size:14px;
    // font-weight:bold; color:#2c3e50` — bold dark digit, NOT the
    // light label style (was the same 12.5/w600 label style as the
    // "Competency:" label above it).
    final indexStyle = TextStyle(
      color: const Color(0xFF2C3E50),
      fontSize: 14,
      fontWeight: FontWeight.bold,
      height: 1.3,
    );
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
        // CSS ref `@767 ::before`: labels are `color:#2c3e50; font-weight:600`
        // (was `_ink` #212529 for the label prefixes).
        color: Color(0xFF2C3E50),
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      );
      // CSS ref, confirmed via the computed-style inspector on the
      // real "Type: AND" cell: `color:#808B96; font:13.6px Roboto` —
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
        // Web: `.kv-detail-content .table tbody tr{margin:15px}` — the
        // card is inset 15px from every edge (was flush left/right).
        margin: const EdgeInsets.fromLTRB(15, 0, 15, 15),
        padding: const EdgeInsets.fromLTRB(12, 15, 7, 7),
        decoration: BoxDecoration(
          color: const Color(0xFFEBF9FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 28, child: Text('$index', style: indexStyle)),
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
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
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
                    // Web: every detail cell is `text-align:left`, so the
                    // View button sits at the card's left edge like the
                    // labels above it (was `Center`, making it the only
                    // right-placed element in the card).
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _viewButton(context),
                    ),
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

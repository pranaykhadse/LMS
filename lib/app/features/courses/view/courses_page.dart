import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/utils/dev_image_proxy.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/course_image_fallback.dart';
import 'package:lms/app/core/views/elements/pagination_widget.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/model/course_catalog.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/viewmodel/course_catalog_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/offline_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';
import 'package:lms/app/features/courses/view/widgets/course_view_availability.dart';
import 'package:lms/app/features/courses/view/widgets/reviews_modal.dart';
import 'package:lms/app/features/courses/view/widgets/offline_course_action.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/features/dashboard/repository/development_plan_action_repository.dart';
import 'package:lms/app/features/dashboard/viewmodel/dev_plan_membership_view_model.dart';
import 'package:lms/app/features/courses/view/calendar_courses_page.dart';

const _catalogPurple = FigmaTokens.primaryPurple;
const _catalogPink = Color(0xFFB0006D);
const _catalogInk = FigmaTokens.cardTitles;
const _catalogMuted = FigmaTokens.noteBodyText;
const _catalogBackground = FigmaTokens.pageBackground;
const _catalogCalendarBlue = FigmaTokens.primaryPurple;
const _catalogUndoBlue = FigmaTokens.primaryPurple;

/// Course id of whichever card currently has its dev-plan add/remove
/// confirmation overlay open, or null if none. Shared across every card
/// on this page so opening one card's overlay closes any other that was
/// already open, instead of each card tracking that state locally and
/// independently.
final _openDevPlanOverlayId = StateProvider<int?>((ref) => null);

/// CSS ref: .group-item column classes — col-lg-3 (viewport ≥ 992px) → 4
/// per row, col-md-6 (≥ 768px) → 2 per row, col-12 below that → 1 per row.
/// Bootstrap breakpoints are viewport-based, so [width] must be the page
/// (window) width, not the grid's content width.
int _catalogColumns(double width) {
  if (width >= 992) return 4;
  if (width >= 768) return 2;
  return 1;
}

class CoursesPage extends ConsumerStatefulWidget {
  const CoursesPage({super.key});

  @override
  ConsumerState<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<CoursesPage> {
  final _searchController = TextEditingController();
  bool _redirectingUnauthorized = false;
  String? _selectedSkillId;

  // Extra breathing room below the last card so it isn't flush against the
  // screen edge / home indicator.
  static const _bottomSpacer = SliverToBoxAdapter(child: SizedBox(height: 32));

  @override
  void initState() {
    super.initState();
    // The provider (now kept alive, not autoDispose - see
    // course_catalog_view_model.dart) already holds whatever filters were
    // last applied, e.g. after coming back from a course detail page. Seed
    // the search box / skill dropdown from it so the UI matches the
    // already-filtered results being shown, instead of appearing reset.
    final applied = ref.read(CourseCatalogViewModel.provider);
    _searchController.text = applied.search;
    _selectedSkillId = applied.skillId ?? applied.behaviorId;
    // Auto-commit the search text a moment after typing stops, instead of
    // only on the explicit Search button/Enter key - otherwise a term
    // typed but never submitted just sits in the box looking like an
    // applied filter while the results underneath stay unfiltered. The
    // debounce itself lives on the notifier (queueSearch), not a Timer
    // here - a widget-owned Timer got silently cancelled by dispose()
    // whenever the user typed and tapped into a course before it fired,
    // so the just-typed filter never actually landed.
    _searchController.addListener(_onSearchTextChanged);
  }

  void _onSearchTextChanged() {
    ref
        .read(CourseCatalogViewModel.provider.notifier)
        .queueSearch(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _changeGroupPage(String groupId, int page) async {
    final error = await ref
        .read(CourseCatalogViewModel.provider.notifier)
        .changeGroupPage(groupId, page);
    if (error != null && mounted) {
      Toast.error(context, error);
    }
  }

  void _applyCatalogFilters() {
    final options = ref.read(CourseCatalogViewModel.provider).filterOptions;
    final selected = _selectedSkill(options, _selectedSkillId);
    ref
        .read(CourseCatalogViewModel.provider.notifier)
        .applyFilters(
          search: _searchController.text,
          skillId:
              selected != null && !_isBehaviorFilter(selected)
                  ? selected.id
                  : null,
          behaviorId:
              selected != null && _isBehaviorFilter(selected)
                  ? selected.id
                  : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(CourseCatalogViewModel.provider);
    final offlineState = ref.watch(OfflineViewModel.provider);
    final isManualOffline = ref.watch(OfflineModeNotifier.provider);
    final connectionVM = ref.watch(InternetConnectionProvider.provider);
    ref.watch(SyncViewModel.provider);
    final response = catalogState.result.data;
    final effectivelyOffline = isManualOffline || !connectionVM.isConnected;
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    // CSS ref, confirmed against `origin/staging`'s catalogue.php own
    // inline <style>: `.container { padding: 0 40px !important }`
    // unconditionally, dropping to `padding: 0 !important` only at
    // `@media (max-width: 540px)` — NOT the generic Bootstrap `.container`
    // 991.98px breakpoint used elsewhere in the app. This page's own
    // inline <style> block renders later in the DOM (view body, after the
    // asset-bundle CSS in <head>), so it wins the cascade specifically
    // here, keeping the page's outer 40px side margin all the way down to
    // 541px before dropping straight to 0.
    final containerWide = MediaQuery.sizeOf(context).width > 540;

    if (!effectivelyOffline &&
        !_redirectingUnauthorized &&
        isUnauthorizedError(catalogState.result.error)) {
      _redirectingUnauthorized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        redirectToLoginOnSessionExpired(context, ref);
      });
    }

    return AppScaffold(
      backgroundColor: _catalogBackground,
      title: 'Course Catalog',
      selectedLabel: 'Course Catalog',
      onRefresh:
          () => ref.read(CourseCatalogViewModel.provider.notifier).fetch(),
      body: RefreshIndicator(
        onRefresh: () async {
          if (effectivelyOffline) return;
          await ref.read(CourseCatalogViewModel.provider.notifier).fetch();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              // CSS ref, confirmed against `origin/staging`'s
              // _searchCatalogue.php: `<div class="py-2"><div
              // class="search-blcok">` — Bootstrap's `.py-2` is a flat,
              // non-responsive 8px top AND bottom (0.5rem), not the
              // 16/24px "breathing room" guess this used before — that
              // was never actually confirmed against source, and was
              // visibly too much gap between the navbar and the search
              // bar on a live comparison.
              padding: EdgeInsets.fromLTRB(
                containerWide ? 40 : 0,
                8,
                containerWide ? 40 : 0,
                8,
              ),
              // CSS ref, confirmed against `origin/staging`: the real
              // zero-results page (`_searchNoResult.php`, rendered by the
              // same `search-result` action `_searchCatalogue.php` posts
              // to) swaps out the modern 5-field panel entirely for a
              // plain 3-field one (Search / Skills / Undo) — it does not
              // repeat the modern panel above the "No results" message.
              // Offline mode has no web equivalent, so it always keeps
              // the modern panel (disabled fields) regardless.
              sliver: SliverToBoxAdapter(
                child:
                    !effectivelyOffline && _isEmptySearchResults(catalogState)
                        ? _LegacySearchBar(
                          searchController: _searchController,
                          skills: catalogState.filterOptions,
                          selectedSkillId: _selectedSkillId,
                          onSkillChanged: (value) {
                            setState(() => _selectedSkillId = value);
                            _applyCatalogFilters();
                          },
                          onApply: _applyCatalogFilters,
                          onReset: () {
                            _searchController.clear();
                            setState(() => _selectedSkillId = null);
                            ref
                                .read(CourseCatalogViewModel.provider.notifier)
                                .reset();
                          },
                        )
                        : _FilterPanel(
                          searchController: _searchController,
                          skills: catalogState.filterOptions,
                          selectedSkillId: _selectedSkillId,
                          offline: effectivelyOffline,
                          onSkillChanged: (value) {
                            setState(() => _selectedSkillId = value);
                            _applyCatalogFilters();
                          },
                          onApply: _applyCatalogFilters,
                          onReset: () {
                            _searchController.clear();
                            setState(() => _selectedSkillId = null);
                            ref
                                .read(CourseCatalogViewModel.provider.notifier)
                                .reset();
                          },
                          onCalendarView:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CalendarCoursesPage(),
                                ),
                              ),
                        ),
              ),
            ),
            if (effectivelyOffline)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 48 : 20,
                  14,
                  isWide ? 48 : 20,
                  12,
                ),
                sliver: const SliverToBoxAdapter(
                  child: Text(
                    'Offline Courses',
                    style: TextStyle(
                      color: _catalogPink,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            if (effectivelyOffline)
              ..._buildOfflineContent(offlineState.courses)
            else
              ..._buildContent(catalogState),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOfflineContent(DataState<List<Course>> state) {
    switch (state.state) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: _catalogPurple),
            ),
          ),
        ];
      case DataProviderState.error:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _CatalogError(
              message: 'Unable to load offline courses.',
              onRetry: null,
            ),
          ),
        ];
      case DataProviderState.data:
        final courses = state.data ?? const <Course>[];
        if (courses.isEmpty) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No offline courses found.\nConnect to the internet and save a course first.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            // 48/27 page padding + the same 15px grid inset the catalog's
            // div.row gets (Bootstrap negative margins commented out), so
            // both grids render identical card geometry.
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width >= 760 ? 63 : 42,
            ),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns = _catalogColumns(
                  MediaQuery.sizeOf(context).width,
                );
                // Same card-geometry formula as the real catalog grid (see
                // `_groupBlock`): the image height is a fluid 16:9 of the
                // card's own width (CSS `.card-image-wrapper` padding-top:
                // 56.25%), so it has to be recomputed from the actual
                // available width rather than pinned to one fixed number.
                const gap = 30.0;
                final cardWidth = (width - (columns - 1) * gap) / columns;
                final imageHeight = cardWidth * 9 / 16;
                final contentBudget = columns == 4 ? 172.0 : 200.0;
                final extent = imageHeight + contentBudget;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    // CSS ref: same card metrics as the catalog grid — 30px
                    // gutters (col padding 15px + 15px), 30px .group-item
                    // margin-bottom.
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                    mainAxisExtent: extent,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _CatalogCourseCard(
                      course: _CourseCardData.fromOffline(courses[index]),
                    ),
                    childCount: courses.length,
                  ),
                );
              },
            ),
          ),
          _bottomSpacer,
          const SliverToBoxAdapter(child: AppFooter()),
        ];
    }
  }

  /// Whether [catalogState] is the zero-results state — data has loaded,
  /// but both `groups` and the flat `courses` list are empty.
  ///
  /// On the real site this isn't just a different message: the whole
  /// `search-result` controller action renders a different view
  /// (`_searchNoResult.php`, confirmed on `origin/staging`) that swaps out
  /// the modern 5-field filter panel for a plain 3-field one (see
  /// [_LegacySearchBar]), rather than repeating the modern panel above the
  /// message.
  bool _isEmptySearchResults(CourseCatalogState catalogState) {
    if (catalogState.result.state != DataProviderState.data) return false;
    final response = catalogState.result.data;
    final groups = response?.groups ?? const <CatalogCourseGroup>[];
    if (groups.isNotEmpty) return false;
    final courses = response?.courses ?? const <CatalogCourse>[];
    return courses.isEmpty;
  }

  List<Widget> _buildContent(CourseCatalogState catalogState) {
    switch (catalogState.result.state) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: _catalogPurple),
            ),
          ),
        ];
      case DataProviderState.error:
        if (isUnauthorizedError(catalogState.result.error)) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: _catalogPurple),
              ),
            ),
          ];
        }
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _CatalogError(
              message: catalogState.result.error ?? 'Unable to load courses.',
              onRetry:
                  () =>
                      ref
                          .read(CourseCatalogViewModel.provider.notifier)
                          .fetch(),
            ),
          ),
        ];
      case DataProviderState.data:
        final response = catalogState.result.data;
        final groups = response?.groups ?? const <CatalogCourseGroup>[];
        if (groups.isNotEmpty) {
          return [
            for (final group in groups)
              _groupBlock(
                group,
                catalogState.groupPages[group.id] ?? group.pagination.page,
              ),
            _bottomSpacer,
            const SliverToBoxAdapter(child: AppFooter()),
          ];
        }

        final courses = response?.courses ?? const <CatalogCourse>[];
        if (courses.isEmpty) {
          return [
            _emptySearchResults(_searchController.text.trim()),
            _bottomSpacer,
            const SliverToBoxAdapter(child: AppFooter()),
          ];
        }
        return [
          _groupBlock(
            CatalogCourseGroup(
              id: 'available',
              name: 'Available',
              pagination: const CatalogPagination(),
              courses: courses,
            ),
            1,
          ),
          _bottomSpacer,
          const SliverToBoxAdapter(child: AppFooter()),
        ];
    }
  }

  /// CSS ref: captured from a live zero-result search (`?CourseSearch[name]=
  /// dfg`) — two stacked `#my-courses` blocks. The first is just
  /// `<h1>No results for "dfg"</h1>` (.heading h1 — font-weight normal,
  /// 28px/33px, color #4A4A4A, margin-bottom 20px). The second is a
  /// fallback `.sec-title` (h2 "Courses to get you started" + h5.title2
  /// "Course Catalog" link back to the base catalog) with no course cards
  /// under it in the capture — reproduced here as the same header pattern
  /// already used by `_groupBlock`, just with an empty body.
  Widget _emptySearchResults(String query) {
    final width = MediaQuery.sizeOf(context).width;
    // CSS ref, confirmed against `origin/staging`: `.container` (catalogue
    // .php inline override) — 40px side padding above 540px, 0 at/below.
    final containerWide = width > 540;
    // CSS ref: `#my-courses` box — padding 30px (>=992), 15px below; the
    // same `@media (max-width: 540px)` block that zeroes `.container`
    // padding also removes this box's border (background stays white).
    final boxWide = width >= 992;
    // CSS ref: `.heading h1` ("No results for…") — 28px/mb-20/lh-33 base,
    // dropping to 20px/mb-15/lh-24 below 992px (Bootstrap's own lg
    // breakpoint, not the 640px used by `.sec-title h2` below).
    final headingWide = width >= 992;
    // CSS ref: `#my-courses .sec-title h2` / `h5 a` — 24px/19px base,
    // dropping to 20px/14px at max-width: 640px.
    final titleWide = width > 640;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        containerWide ? 40 : 0,
        14,
        containerWide ? 40 : 0,
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CSS ref: #my-courses — bg #fff, border 1px #E7E4FF (removed
            // <=540), radius 14px, padding 30px (>=992) / 15px below.
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(boxWide ? 30 : 15),
              decoration: BoxDecoration(
                color: Colors.white,
                border:
                    containerWide
                        ? Border.all(color: const Color(0xFFE7E4FF))
                        : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                query.isEmpty ? 'No results found' : 'No results for "$query"',
                style: GoogleFonts.inter(
                  color: const Color(0xFF4A4A4A),
                  fontSize: headingWide ? 28 : 20,
                  fontWeight: FontWeight.normal,
                  height: headingWide ? 33 / 28 : 24 / 20,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // CSS ref: #resources .sec-title — h2 "Courses to get you
            // started" + h5.title2 underlined "Course Catalog" link,
            // right-aligned via margin-left: auto.
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(boxWide ? 30 : 15),
              decoration: BoxDecoration(
                color: Colors.white,
                border:
                    containerWide
                        ? Border.all(color: const Color(0xFFE7E4FF))
                        : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Courses to get you started',
                    style: GoogleFonts.inter(
                      color: _catalogPink,
                      fontSize: titleWide ? 24 : 20,
                      fontWeight: FontWeight.normal,
                      height: titleWide ? 28 / 24 : 26 / 20,
                    ),
                  ),
                  const Spacer(),
                  HoverBuilder(
                    cursor: SystemMouseCursors.click,
                    builder:
                        (context, hovering) => GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            ref
                                .read(CourseCatalogViewModel.provider.notifier)
                                .queueSearch('');
                          },
                          child: Text(
                            'Course Catalog',
                            style: GoogleFonts.inter(
                              color:
                                  hovering
                                      ? _catalogPurple
                                      : const Color(0xFF767676),
                              fontSize: titleWide ? 19 : 14,
                              height: 23 / 19,
                              decoration: TextDecoration.underline,
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
    );
  }

  /// CSS ref: div#resources — bg #fff, border 1px #E7E4FF, border-radius
  /// 14px, padding 30px, margin 0. div.sec-title is its first child; then
  /// div.resources-block (empty .summary, .row of cards, div.pagination.m-2).
  Widget _groupBlock(CatalogCourseGroup group, int selectedPage) {
    final width = MediaQuery.sizeOf(context).width;
    // CSS ref, confirmed against `origin/staging`: `.container` (catalogue
    // .php inline override) — 40px side padding above 540px, 0 at/below.
    final containerWide = width > 540;
    // CSS ref: `#resources` box — padding 30px (>=992), 15px below; the
    // same `@media (max-width: 540px)` block that zeroes `.container`
    // padding also removes this box's border (background stays white).
    final boxWide = width >= 992;
    // CSS ref: `#resources .sec-title h2` — 24px/400/lh-28 base, dropping
    // to 20px/lh-26 at max-width: 640px.
    final titleWide = width > 640;
    final hPad = containerWide ? 40.0 : 0.0;
    final title =
        group.name.trim().isEmpty ? 'Courses' : '${group.name} Courses';

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
      sliver: SliverToBoxAdapter(
        child: Container(
          // CSS: bg #fff, border 1px #E7E4FF (removed <=540), radius 14px,
          // padding 30px (>=992) / 15px below.
          decoration: BoxDecoration(
            color: Colors.white,
            border:
                containerWide
                    ? Border.all(color: const Color(0xFFE7E4FF))
                    : null,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: EdgeInsets.all(boxWide ? 30 : 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // div.sec-title h2.title — inside div#resources:
              // font-size 24px, font-weight 400 (the ID selector overrides
              // Bootstrap's h1-h6 500 reset), line-height 28px,
              // margin-bottom 20px, color var(--primary-second) = #A20067.
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFA20067),
                    fontSize: titleWide ? 24 : 20,
                    fontWeight: FontWeight.w400,
                    height: titleWide ? 28 / 24 : 26 / 20,
                  ),
                ),
              ),
              // Card grid
              // CSS ref: div.row — display: flex; flex-wrap: wrap; with
              // Bootstrap's negative margins (margin: 0 -15px) COMMENTED
              // OUT, so the edge columns keep their outer 15px col padding:
              // the grid is inset 15px from #resources' content box on both
              // sides (computed .row box: 1392 x 1070, margin/padding 0).
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Bootstrap breakpoints are viewport-based (col-lg-3 /
                    // col-md-6), so decide columns from the page width.
                    final columns = _catalogColumns(
                      MediaQuery.sizeOf(context).width,
                    );
                    // CSS ref: .group-item margin-bottom 30px between rows;
                    // col-* padding 15px + 15px = 30px gutter between columns.
                    final gap = 30.0;
                    // CSS ref: .card-image-wrapper — padding-top: 56.25%
                    // (16:9) of the card's OWN fluid width, not a fixed
                    // pixel value — so the card height must be recomputed
                    // from the actual available width at every render, not
                    // pinned to whatever one viewport it was last measured
                    // at. `constraints.maxWidth` here is the grid's
                    // content width (after the 15px inset above), so this
                    // reproduces exactly what one `col-lg-3`/`col-md-6`
                    // column's width resolves to at the current viewport.
                    final cardWidth =
                        (constraints.maxWidth - (columns - 1) * gap) / columns;
                    final imageHeight = cardWidth * 9 / 16;
                    // Below-image content is padding/font/line-height sums
                    // — none of it is percentage-based, so unlike the
                    // image this genuinely is a fixed budget per
                    // column-count tier. Live-measured at the 4-column
                    // breakpoint: 352px card - 180px image = 172px; at the
                    // 1-column breakpoint: 380 - 180 = 200px.
                    //
                    // That 172/200 budget was measured against a card
                    // showing EITHER the "NEXT AVAILABLE" session block OR
                    // the star-rating bar, not both stacked together — a
                    // card with both (e.g. a short 1-line title, so the
                    // title's own shorter height didn't offset it) actually
                    // needs the session block's own ~38px on top of that,
                    // and overflowed by a few px (RenderFlex "BOTTOM
                    // OVERFLOWED" debug banner) since the whole row's fixed
                    // `mainAxisExtent` was too short for it. Widened by the
                    // session block's height whenever any card in this
                    // group actually carries both, so groups that never mix
                    // the two keep their original (tighter) row height.
                    final hasSessionAndRating = group.courses.any(
                      (c) =>
                          c.nextSession != null &&
                          c.displayRating &&
                          c.averageRating > 0,
                    );
                    const sessionBlockHeight = 40.0;
                    final contentBudget =
                        (boxWide ? 172.0 : 200.0) +
                        (hasSessionAndRating ? sessionBlockHeight : 0);
                    final extent = imageHeight + contentBudget;
                    final rows = (group.courses.length / columns).ceil();
                    final gridH = rows * extent + (rows - 1) * gap;
                    return SizedBox(
                      height: gridH,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: gap,
                          mainAxisSpacing: gap,
                          mainAxisExtent: extent,
                        ),
                        itemCount: group.courses.length,
                        itemBuilder: (context, index) {
                          final course = _CourseCardData.fromCatalog(
                            group.courses[index],
                          );
                          // Keyed by course id so pagination/group changes
                          // fully dispose and recreate each card's state
                          // (hover, busy, dev-plan overlay) rather than
                          // Flutter reusing State objects at the same grid
                          // position for a different course.
                          return _CatalogCourseCard(
                            key: ValueKey(course.id),
                            course: course,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              // CSS ref: div.pagination.m-2 — 8px margins around the pager,
              // stacked on the last row's .group-item margin-bottom: 30px
              // (the flex .row's height includes it), so 38px total sits
              // between the last card and the pager. The web's #resources
              // holds no per-page badge, only the pager.
              if (group.pagination.pages > 1) ...[
                const SizedBox(height: 38),
                PaginationWidget(
                  page: selectedPage,
                  pages: group.pagination.pages,
                  onPage: (page) => _changeGroupPage(group.id, page),
                  // CSS ref: .pagination-footer / .pg-progress-container /
                  // .pg-progress-bar / .pg-status-text — blueprint-exact
                  // progress footer, opt-in here only so the other 7+
                  // screens using this shared widget keep their current
                  // look.
                  showProgressBar: true,
                  // Reverted: catalogue.php's raw LinkPager PHP config
                  // (prevPageCssClass/nextPageCssClass: 'd-none', no
                  // firstPageLabel/lastPageLabel) implied hidden arrows
                  // and a plain sliding window with no ellipsis — but a
                  // live screenshot of the actual dev site shows prev/
                  // next arrows AND pinned-first/ellipsis/pinned-last
                  // (e.g. "< 1 2 3 … 10 >"), meaning something beyond
                  // that static PHP call (likely JS) actually drives the
                  // real rendering. Keeping this widget's original
                  // default behavior, which already matched.
                ),
                const SizedBox(height: 8),
              ] else
                // No pager — the trailing .group-item margin-bottom still
                // applies below the last row of cards.
                const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
} // end _CoursesPageState

class _FilterPanel extends StatefulWidget {
  const _FilterPanel({
    required this.searchController,
    required this.skills,
    required this.selectedSkillId,
    required this.offline,
    required this.onSkillChanged,
    required this.onApply,
    required this.onReset,
    required this.onCalendarView,
  });

  final TextEditingController searchController;
  final List<CatalogSkill> skills;
  final String? selectedSkillId;
  final bool offline;
  final ValueChanged<String?> onSkillChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;
  final VoidCallback onCalendarView;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  // CSS ref: .filter-content — display: none by default below 992px,
  // toggled to display:block by .filter-mobile-toggle's click handler
  // (adds/removes an `.active` class on both elements).
  bool _mobileExpanded = false;

  @override
  Widget build(BuildContext context) {
    final searchController = widget.searchController;
    final skills = widget.skills;
    final selectedSkillId = widget.selectedSkillId;
    final offline = widget.offline;
    final onSkillChanged = widget.onSkillChanged;
    final onApply = widget.onApply;
    final onReset = widget.onReset;
    final onCalendarView = widget.onCalendarView;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // CSS ref, confirmed against `origin/staging`'s
        // backend/views/course/_searchCatalogue.php: the toggle is
        // `.filter-mobile-toggle.d-lg-none` — hidden only at Bootstrap's
        // `lg` breakpoint, 992px, not the 720px this used to check.
        final wide = width >= 992;

        // CSS ref: search input — rounded-[12px] border-[#e2e8f0] bg-[#f8fafc] h-[42px] px-4.
        // No `showClear` — confirmed against `origin/staging`'s
        // _searchCatalogue.php: the real field template is just
        // `<i class="fas fa-search"></i>{input}`, no clear/close
        // affordance at all.
        final searchField = _CatalogField(
          controller: searchController,
          hint: offline ? "You're offline" : 'Search',
          showLeadingIcon: true,
          enabled: !offline,
          onSubmitted: (_) => onApply(),
        );

        // CSS ref: Strategic Imperative input — same style as search
        final strategicField = _CatalogField(
          hint: 'Strategic Imperative',
          showLeadingIcon: true,
          enabled: !offline,
        );

        // CSS ref: Competencies input — same style as search
        final competenciesField = _CatalogField(
          hint: 'Competencies',
          showLeadingIcon: true,
          enabled: !offline,
        );

        // CSS ref, confirmed against `origin/staging`: select2 opens as a
        // normal in-page dropdown (`.select2-dropdown`) positioned under
        // its trigger at every viewport width — it never switches to a
        // native-style bottom sheet. `inline: true` unconditionally
        // reproduces that; the bottom-sheet variant was a Flutter-only
        // mobile-UX pattern with no web counterpart.
        final skillDropdown = _SkillDropdown(
          skills: skills,
          value: selectedSkillId,
          onChanged: onSkillChanged,
        );

        // CSS ref: undo-btn — bg-[#f1f5f9] text-[#64748b] rounded-[12px] h-[42px] w-[30%]
        // hover: background-color #e2e8f0, color #1e293b (icon + bg both
        // change on hover, not just bg).
        final undoButton = SizedBox(
          height: 42,
          child: HoverBuilder(
            cursor:
                offline ? SystemMouseCursors.basic : SystemMouseCursors.click,
            builder:
                (context, hovering) => GestureDetector(
                  onTap: offline ? null : onReset,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color:
                          hovering
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    // CSS ref, confirmed against live computed style: i.fa-undo
                    // — 14px, color #64748B.
                    child: Icon(
                      Icons.undo_rounded,
                      size: 14,
                      color:
                          hovering
                              ? const Color(0xFF1E293B)
                              : const Color(0xFF64748B),
                    ),
                  ),
                ),
          ),
        );

        // CSS ref: calendar-btn — bg-[#693D94] rounded-[12px] font-semibold text-[13px] h-[42px]
        // hover: background-color #4345a0 (not --primary-dark #5A3480),
        // transform translateY(-2px), box-shadow escalates to
        // 0 6px 15px rgba(84,87,193,0.3).
        final calendarButton = HoverBuilder(
          cursor: SystemMouseCursors.click,
          builder:
              (context, hovering) => GestureDetector(
                onTap: onCalendarView,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  transform: Matrix4.translationValues(0, hovering ? -2 : 0, 0),
                  height: 42,
                  // CSS ref, confirmed against live computed style: the
                  // stylesheet's literal `.calendar-btn { padding: 0 5px }`
                  // rule loses to `.btn-primary { padding: 0 20px }` — same
                  // specificity (both `.search-blcok .<class>`), but
                  // `.btn-primary` is declared later in the file, so it wins.
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color:
                        hovering
                            ? const Color(0xFF4345A0)
                            : _catalogCalendarBlue,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFF5457C1,
                        ).withValues(alpha: hovering ? 0.3 : 0.2),
                        blurRadius: hovering ? 15 : 12,
                        offset: Offset(0, hovering ? 6 : 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Calendar View',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
        );

        // CSS ref: search-blcok — bg-white rounded-[16px] p-[10px] shadow border-[#f0f1f5]
        const outerDecoration = BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        );

        if (wide) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: outerDecoration.copyWith(
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.05),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0xFFF0F1F5)),
            ),
            // CSS ref, confirmed against the live DOM: 5 equal-width
            // `.col-lg` columns (Search / Strategic Imperative /
            // Competencies / Skills / Actions), each measuring identically
            // (202.8px at this viewport) with a constant 15px gap between
            // every column — not the 8px this used to use, and not 6
            // separate items (undo/calendar are one column, split 30:70
            // internally per `.undo-btn { flex: 0 0 calc(30% - 4px) }` /
            // `.calendar-btn { flex: 0 0 calc(70% - 4px) }` with their own
            // 8px gap), so both buttons stretch to fill that column's
            // share of the row instead of sizing to their own content.
            child: Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 15),
                Expanded(child: strategicField),
                const SizedBox(width: 15),
                Expanded(child: competenciesField),
                const SizedBox(width: 15),
                Expanded(child: skillDropdown),
                const SizedBox(width: 15),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(flex: 30, child: undoButton),
                      const SizedBox(width: 8),
                      Expanded(flex: 70, child: calendarButton),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile: collapsed behind a "Filters" toggle by default.
        // CSS ref: .filter-mobile-toggle — padding 12px 15px, bg #f8fafc,
        // radius 12px; span — font-weight 600, font-size 15px, color
        // #1e293b; i (filter/chevron icons) — color var(--primary-color),
        // font-size 16px; chevron rotates 180deg when .active.
        // .filter-content — display:none until .active, then padding-top
        // 15px, margin-top 10px, border-top 1px #f1f5f9.
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: outerDecoration.copyWith(
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.05),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFF0F1F5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _mobileExpanded = !_mobileExpanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.filter_list_rounded,
                            size: 16,
                            color: _catalogPurple,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Filters',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: const Color(0xFF1E293B),
                              // CSS ref: .filter-mobile-toggle span has no
                              // own line-height, inherits body's 1.5.
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 300),
                        turns: _mobileExpanded ? 0.5 : 0,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: _catalogPurple,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState:
                    _mobileExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.only(top: 15),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  // CSS ref, confirmed against `origin/staging`'s
                  // _searchCatalogue.php: below 992px these 5 fields sit
                  // in a Bootstrap `.row` (flex-wrap) using
                  // `col-lg col-md-4 col-sm-6` / `col-md-6 col-sm-6` /
                  // `col-md-6 col-sm-12` — so the wrap pattern actually
                  // changes again at 768px and 576px, not just once.
                  child: _CatalogFilterWrap(
                    searchField: searchField,
                    strategicField: strategicField,
                    competenciesField: competenciesField,
                    skillDropdown: skillDropdown,
                    actionsRow: Row(
                      children: [
                        Expanded(flex: 30, child: undoButton),
                        const SizedBox(width: 8),
                        Expanded(flex: 70, child: calendarButton),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The expanded mobile filter panel's field layout, below 992px.
///
/// CSS ref, confirmed against `origin/staging`'s
/// backend/views/course/_searchCatalogue.php: the 5 fields sit in one
/// Bootstrap `.row` (always `display:flex; flex-wrap:wrap`) with classes
/// `col-lg col-md-4 col-sm-6` (search/strategic/competencies),
/// `col-lg col-md-6 col-sm-6` (skill), and `col-lg col-md-6 col-sm-12`
/// (actions). Since `.col-lg`/`.col-md-4`/`.col-sm-6` etc. all carry a base
/// `width:100%` and only their own breakpoint's `min-width` media query
/// overrides that with a flex-basis percentage, the wrap pattern is
/// genuinely different at each tier:
///   - >=768 (md): row of 3 equal thirds (search/strategic/competencies),
///     then a row of 2 equal halves (skill/actions).
///   - 576-767 (sm): 2-then-2-then-1 — (search/strategic),
///     (competencies/skill), then actions alone at full width.
///   - <576 (xs): no col-{bp} class is active at all, so every field falls
///     back to its base `width:100%` and stacks one per row.
/// Vertical gap between wrapped rows is `.search-blcok .row > div` —
/// margin-bottom 15px (only the mobile media query sets this; last child
/// has none, handled here by only inserting gaps between rows). Horizontal
/// gap reuses the same 15px measured live for the desktop single-row
/// layout — same `.row`/`.col-*` classes, so the same gutter math applies.
class _CatalogFilterWrap extends StatelessWidget {
  const _CatalogFilterWrap({
    required this.searchField,
    required this.strategicField,
    required this.competenciesField,
    required this.skillDropdown,
    required this.actionsRow,
  });

  final Widget searchField;
  final Widget strategicField;
  final Widget competenciesField;
  final Widget skillDropdown;
  final Widget actionsRow;

  static const _gap = 15.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= 768) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: _gap),
                  Expanded(child: strategicField),
                  const SizedBox(width: _gap),
                  Expanded(child: competenciesField),
                ],
              ),
              const SizedBox(height: _gap),
              Row(
                children: [
                  Expanded(child: skillDropdown),
                  const SizedBox(width: _gap),
                  Expanded(child: actionsRow),
                ],
              ),
            ],
          );
        }

        if (width >= 576) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: _gap),
                  Expanded(child: strategicField),
                ],
              ),
              const SizedBox(height: _gap),
              Row(
                children: [
                  Expanded(child: competenciesField),
                  const SizedBox(width: _gap),
                  Expanded(child: skillDropdown),
                ],
              ),
              const SizedBox(height: _gap),
              actionsRow,
            ],
          );
        }

        return Column(
          children: [
            searchField,
            const SizedBox(height: _gap),
            strategicField,
            const SizedBox(height: _gap),
            competenciesField,
            const SizedBox(height: _gap),
            skillDropdown,
            const SizedBox(height: _gap),
            actionsRow,
          ],
        );
      },
    );
  }
}

/// The plain 3-field search bar shown instead of the modern
/// [_FilterPanel] when a search returns zero results.
///
/// CSS ref, confirmed against `origin/staging`'s
/// backend/views/course/_searchNoResult.php: this is a genuinely
/// different, older-styled form — `.search-blcok` here has none of
/// `_searchCatalogue.php`'s modern white-card/shadow/radius/rounded-field
/// styling, because that's all defined in a page-scoped inline `<style>`
/// block that only exists on `_searchCatalogue.php`, not this view. Fields
/// fall back to plain Bootstrap `.form-control` and default select2
/// theming. Columns are `col-lg-5 col-md-12 col-sm-12 col-12` (search),
/// `col-lg-6 col-md-11 col-sm-12 col-12` (skills), `col-lg-1 col-md-1
/// col-sm-12` (undo) — those only fit on one row at >=992px; every
/// combination below that overflows pairwise, so in practice it's a
/// binary wide-row/narrow-stack layout, not a multi-tier wrap like the
/// modern panel's.
class _LegacySearchBar extends StatelessWidget {
  const _LegacySearchBar({
    required this.searchController,
    required this.skills,
    required this.selectedSkillId,
    required this.onSkillChanged,
    required this.onApply,
    required this.onReset,
  });

  final TextEditingController searchController;
  final List<CatalogSkill> skills;
  final String? selectedSkillId;
  final ValueChanged<String?> onSkillChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final searchField = _LegacySearchField(
      controller: searchController,
      onSubmitted: (_) => onApply(),
    );
    final skillDropdown = _LegacySkillDropdown(
      skills: skills,
      value: selectedSkillId,
      onChanged: onSkillChanged,
    );
    final undoButton = _LegacyUndoButton(onTap: onReset);

    // CSS ref: .search-blcok — margin: 30px 0 0 0 (only rule that applies
    // on this page; no background/padding/border/shadow).
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 992) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 5, child: searchField),
                const SizedBox(width: 15),
                Expanded(flex: 6, child: skillDropdown),
                const SizedBox(width: 15),
                Expanded(flex: 1, child: undoButton),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 15),
              skillDropdown,
              const SizedBox(height: 15),
              undoButton,
            ],
          );
        },
      ),
    );
  }
}

class _LegacySearchField extends StatelessWidget {
  const _LegacySearchField({required this.controller, this.onSubmitted});
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    // CSS ref: .form-control (plain Bootstrap, no modern override here) —
    // height 42px, border 1px #E7E4FF, border-radius 0.25rem (4px). .search
    // i — position absolute, left 10px, top 12px, color #693D94, font-size
    // 20px (the template places the <i> markup after {input}, but absolute
    // positioning still puts it visually on the left).
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFFE7E4FF)),
    );
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF495057)),
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFF999999),
            fontSize: 14,
          ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF693D94),
            size: 20,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 20,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}

class _LegacySkillDropdown extends StatelessWidget {
  const _LegacySkillDropdown({
    required this.skills,
    required this.value,
    required this.onChanged,
  });
  final List<CatalogSkill> skills;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    // CSS ref: .select-search — border 1px #E7E4FF, height 42px, bg
    // #fff, padding 6px, border-radius 14px — wrapping a default select2
    // box (bg #f4f4f4, border-radius 3px) rather than the modern
    // `_searchCatalogue.php`-only rounded/f8fafc select2 override.
    return Container(
      height: 42,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7E4FF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(3),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButtonFormField<String?>(
            initialValue: value,
            isExpanded: true,
            isDense: true,
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF693D94)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            hint: Text(
              'Skills or Behavior',
              style: GoogleFonts.inter(
                color: const Color(0xFF999999),
                fontSize: 13,
              ),
            ),
            style: GoogleFonts.inter(
              color: const Color(0xFF495057),
              fontSize: 13,
            ),
            items: [
              for (final skill in skills)
                DropdownMenuItem(value: skill.id, child: Text(skill.name)),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _LegacyUndoButton extends StatelessWidget {
  const _LegacyUndoButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // CSS ref: <a class="btn btn-primary undo-btn"> — .btn-primary bg
    // #693D94, color #fff, hover #4345a0; .undo-btn overrides padding to
    // 7px 15px !important (line-height: unset). Default .btn border-radius
    // 0.25rem (4px) — NOT the modern 42px gray-pill circle from
    // `_searchCatalogue.php`'s own scoped `.search-blcok .undo-btn`
    // override, which isn't loaded on this page.
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder:
          (context, hovering) => GestureDetector(
            onTap: onTap,
            child: Container(
              height: 42,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
              decoration: BoxDecoration(
                color:
                    hovering
                        ? const Color(0xFF4345A0)
                        : const Color(0xFF693D94),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.undo_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
    );
  }
}

class _CatalogField extends StatelessWidget {
  const _CatalogField({
    this.controller,
    required this.hint,
    this.enabled = true,
    this.showLeadingIcon = true,
    this.onSubmitted,
  });
  final TextEditingController? controller;
  final String hint;
  final bool enabled;
  final bool showLeadingIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    // No `showClear` — confirmed against `origin/staging`'s
    // _searchCatalogue.php: none of the catalog filter fields have a
    // clear/close affordance in the real markup.
    return _ClearableTextField(
      controller: controller,
      enabled: enabled,
      hint: hint,
      showLeadingIcon: showLeadingIcon,
      onSubmitted: onSubmitted,
    );
  }
}

class _ClearableTextField extends StatefulWidget {
  const _ClearableTextField({
    required this.hint,
    this.controller,
    this.enabled = true,
    this.showLeadingIcon = true,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String hint;
  final bool enabled;
  final bool showLeadingIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_ClearableTextField> createState() => _ClearableTextFieldState();
}

class _ClearableTextFieldState extends State<_ClearableTextField> {
  late final TextEditingController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  bool _focused = false;

  void _handleTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      // CSS ref, confirmed against `origin/staging`: `.form-control` /
      // `.search-blcok .searchInput` both set an explicit `height: 42px`
      // — not a value derived from padding + line-height. Without this,
      // the field sizes itself from its own contentPadding + intrinsic
      // text height (shorter than 42px, since the text style has no
      // explicit `height:` either), rendering visibly shorter than the
      // 42px undo/calendar buttons and skill-dropdown sitting beside it
      // in the same row.
      child: SizedBox(
        height: 42,
        child: Container(
          // CSS ref: .search-blcok .searchInput:focus — box-shadow: 0 0 0
          // 4px rgba(84, 87, 193, 0.1) — a soft glow ring outside the
          // border, which InputDecoration's border alone can't produce in
          // Flutter.
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
            // Remove Flutter's default gray hover color on TextField
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                hoverColor: Colors.transparent,
              ),
            ),
            child: TextField(
              controller: _controller,
              enabled: widget.enabled,
              // The field's height is forced to a fixed 42px (see the
              // SizedBox above) while the natural text+padding content is
              // shorter, so without this the InputDecorator top-aligns the
              // text/placeholder inside that box (padding measured from
              // the top, extra leftover space pushed to the bottom)
              // instead of centering it — reading as sitting a few px
              // below where the prefixIcon (always vertically centered in
              // the full box height) actually sits.
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF2D3748),
                fontSize: 14,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w400,
                // CSS ref: .form-control line-height: 1.5 (no override for
                // this specific class), matching the explicit height:42
                // box above.
                height: 1.5,
              ),
              onSubmitted: (value) {
                FocusScope.of(context).unfocus();
                widget.onSubmitted?.call(value);
              },
              // No suffix/clear icon — confirmed against `origin/staging`'s
              // _searchCatalogue.php: the real field template is just
              // `<i class="fas fa-search"></i>{input}`, no clear affordance.
              decoration: _fieldDecoration(
                widget.hint,
                showLeadingIcon: widget.showLeadingIcon,
                // CSS ref: focus:background-color: #fff (was #f8fafc when unfocused)
                fillColor: _focused ? Colors.white : const Color(0xFFF8FAFC),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillDropdown extends StatefulWidget {
  const _SkillDropdown({
    required this.skills,
    required this.value,
    required this.onChanged,
  });
  final List<CatalogSkill> skills;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  State<_SkillDropdown> createState() => _SkillDropdownState();
}

class _SkillDropdownState extends State<_SkillDropdown> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _open = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_open && mounted) setState(() => _open = false);
  }

  void _openInline(
    BuildContext context,
    List<CatalogSkill> unique,
    CatalogSkill? selected,
  ) {
    final box = context.findRenderObject() as RenderBox;
    _overlayEntry = OverlayEntry(
      builder:
          (context) => _SkillDropdownOverlay(
            link: _layerLink,
            width: box.size.width,
            skills: unique,
            selectedId: selected?.id,
            onDismiss: _removeOverlay,
            onSelected: (skill) {
              widget.onChanged(skill?.id);
              _removeOverlay();
            },
          ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    final unique =
        <String, CatalogSkill>{
          for (final skill in widget.skills) skill.id: skill,
        }.values.toList();
    final selected = _selectedSkill(unique, widget.value);

    final field = InkWell(
      onTap:
          unique.isEmpty
              ? null
              : () =>
                  _open
                      ? _removeOverlay()
                      : _openInline(context, unique, selected),
      borderRadius: BorderRadius.circular(4),
      // CSS ref: .select2-container--default .select2-selection--single —
      // explicit height: 42px, same as the text fields beside it. Without
      // this, `InputDecorator` sizes itself from contentPadding + the
      // text's intrinsic height, rendering shorter and misaligned against
      // the 42px fields/buttons in the same row.
      child: SizedBox(
        height: 42,
        child: InputDecorator(
          // Same fixed-height-vs-content-height mismatch as the text
          // fields beside it — center the label instead of letting it
          // default to top-aligned within the forced 42px box.
          textAlignVertical: TextAlignVertical.center,
          decoration: _fieldDecoration(
            'Skills or Behavior',
            showLeadingIcon: true, // CSS ref: fa-search prefix icon
          ).copyWith(
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected != null)
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: () {
                      widget.onChanged(null);
                      _removeOverlay();
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                  ),
                Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF94A3B8),
                  size: 18,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          child: Text(
            selected?.name ?? 'Skills or Behavior',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color:
                  selected == null
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF475569),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );

    return CompositedTransformTarget(link: _layerLink, child: field);
  }
}

class _SkillDropdownOverlay extends StatefulWidget {
  const _SkillDropdownOverlay({
    required this.link,
    required this.width,
    required this.skills,
    required this.selectedId,
    required this.onDismiss,
    required this.onSelected,
  });
  final LayerLink link;
  final double width;
  final List<CatalogSkill> skills;
  final String? selectedId;
  final VoidCallback onDismiss;
  final ValueChanged<CatalogSkill?> onSelected;

  @override
  State<_SkillDropdownOverlay> createState() => _SkillDropdownOverlayState();
}

class _SkillDropdownOverlayState extends State<_SkillDropdownOverlay> {
  final _queryController = TextEditingController();
  bool _searchFocused = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text.trim().toLowerCase();
    final filtered =
        widget.skills
            .where((skill) => skill.name.toLowerCase().contains(query))
            .toList();
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 0),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 2,
              // CSS ref: border-top-left-radius:0, border-top-right-radius:0,
              // border-bottom-left-radius:4px, border-bottom-right-radius:4px
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(4),
              ),
              child: Container(
                width: widget.width,
                constraints: const BoxConstraints(maxHeight: 280),
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  // CSS ref: border: 1px solid #aaa, border-top: none
                  border: Border(
                    left: BorderSide(color: Color(0xFFAAAAAA)),
                    right: BorderSide(color: Color(0xFFAAAAAA)),
                    bottom: BorderSide(color: Color(0xFFAAAAAA)),
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(4),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // CSS ref: select2-search padding: 4px all sides
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Focus(
                        onFocusChange:
                            (focused) =>
                                setState(() => _searchFocused = focused),
                        child: Container(
                          // CSS ref: generic `input[type=search]:focus` rule
                          // — box-shadow: 0 0 3px rgba(139, 106, 179, 0.1) —
                          // a soft blurred glow, distinct from the main
                          // search bar's solid 4px ring.
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            boxShadow:
                                _searchFocused
                                    ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF8B6AB3,
                                        ).withValues(alpha: 0.1),
                                        blurRadius: 3,
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
                              controller: _queryController,
                              autofocus: false,
                              onChanged: (_) => setState(() {}),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF475569),
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: '',
                                hoverColor: Colors.transparent,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFAAAAAA),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFAAAAAA),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF693D94),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Text(
                          'No results found',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF2D3748),
                            height: 21 / 14,
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final skill = filtered[index];
                            final selected = skill.id == widget.selectedId;
                            final highlighted =
                                selected ||
                                (widget.selectedId == null && index == 0);
                            return InkWell(
                              onTap: () => widget.onSelected(skill),
                              child: Container(
                                width: double.infinity,
                                color:
                                    highlighted
                                        ? const Color(0xFF5897FB)
                                        : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: Text(
                                  skill.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color:
                                        highlighted
                                            ? Colors.white
                                            : const Color(0xFF2D3748),
                                    fontWeight:
                                        highlighted
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// _SkillPickerSheet (native-style bottom sheet) removed — confirmed
// against `origin/staging`: select2 always opens as an in-page dropdown
// under its trigger, at every viewport width, so the bottom-sheet variant
// had no web counterpart. `_SkillDropdownOverlay` (the inline panel) is
// now used unconditionally instead.

InputDecoration _fieldDecoration(
  String hint, {
  Widget? suffixIcon,
  bool showLeadingIcon = true,
  Color fillColor = const Color(0xFFF8FAFC),
}) => InputDecoration(
  hintText: hint,
  // CSS ref, confirmed against the live DOM's computed
  // getComputedStyle(input, '::placeholder'): font-size 15px, color
  // rgb(108,117,125)/#6C757D, letter-spacing 1px. The letter-spacing
  // comes from `.form-control { letter-spacing: 1px }` (not overridden
  // by the more specific `.search-blcok .searchInput` rule, which
  // never touches it) — it's real, not a stray leftover.
  hintStyle: GoogleFonts.inter(
    color: const Color(0xFF6C757D),
    fontSize: 15,
    letterSpacing: 1.0,
  ),
  // Icon enlarged (14 -> 18) per request, since the original literal
  // 14px read as too small next to the 15px placeholder text. The
  // input/placeholder text is nudged up slightly via contentPadding
  // below (also per request) so it optically centers against the now-
  // larger, vertically-centered icon instead of sitting a hair below it.
  prefixIcon:
      showLeadingIcon
          ? const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18)
          : null,
  suffixIcon: suffixIcon,
  filled: true,
  // CSS ref: background-color: #f8fafc (unfocused), #fff (focused) — passed via fillColor param
  fillColor: fillColor,
  // Remove Flutter's default gray hover overlay
  hoverColor: Colors.transparent,
  isDense: true,
  // CSS ref: .searchInput.form-control padding: 6px 12px 6px 42px
  // (6px vertical, 12px horizontal, 42px left for the icon inset —
  // applied exactly per blueprint).
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  border: OutlineInputBorder(
    // CSS ref: border-radius: 12px
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    // CSS ref: focus:border-color var(--primary-color) — the site's
    // actual brand purple (#693D94), not the leftover indigo #5457C1
    // this previously used, which read as barely different from the
    // unfocused gray border.
    borderSide: const BorderSide(color: _catalogPurple, width: 1.5),
  ),
  disabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
  ),
);

CatalogSkill? _selectedSkill(List<CatalogSkill> skills, String? id) {
  if (id == null) return null;
  for (final skill in skills) {
    if (skill.id == id) return skill;
  }
  return null;
}

bool _isBehaviorFilter(CatalogSkill skill) {
  final groupId = skill.groupId.toLowerCase();
  final name = skill.name.toLowerCase();
  return groupId == '2' || groupId.contains('behav') || name.contains('behav');
}

class _CourseCardData {
  const _CourseCardData({
    required this.id,
    required this.name,
    required this.logo,
    required this.progress,
    required this.nextSession,
    required this.nextSessionLabel,
    required this.offlineCourse,
    this.inDevelopmentPlan = false,
    this.planId,
  });

  final int id;
  final String name;
  final String? logo;
  final double progress;
  final DateTime? nextSession;
  final String? nextSessionLabel;
  final Course offlineCourse;
  final bool inDevelopmentPlan;
  final int? planId;

  factory _CourseCardData.fromCatalog(CatalogCourse course) {
    return _CourseCardData(
      id: course.id,
      name: course.name,
      logo: course.logo,
      progress: course.progress,
      nextSession: course.nextSession,
      nextSessionLabel: course.nextSessionLabel,
      inDevelopmentPlan: course.inDevelopmentPlan,
      planId: course.planId,
      offlineCourse: Course(
        id: course.id,
        name: course.name,
        logoLink: course.logo,
        averageRating: course.averageRating,
        ratingCount: course.ratingCount,
        displayRating: course.displayRating ? 1 : 0,
      ),
    );
  }

  factory _CourseCardData.fromOffline(Course course) {
    return _CourseCardData(
      id: course.id ?? 0,
      name: course.name ?? 'Course',
      logo: course.logoLink,
      progress: course.percentage,
      nextSession: null,
      nextSessionLabel: null,
      offlineCourse: course,
    );
  }
}

class _CatalogCourseCard extends ConsumerStatefulWidget {
  const _CatalogCourseCard({super.key, required this.course});
  final _CourseCardData course;

  @override
  ConsumerState<_CatalogCourseCard> createState() => _CatalogCourseCardState();
}

class _CatalogCourseCardState extends ConsumerState<_CatalogCourseCard> {
  bool _isBusy = false;
  bool _hovering = false;

  void _closeOverlayIfMine() {
    // Only clear the shared id if it's still this card's — avoids
    // accidentally closing a different card's overlay that may have been
    // opened in between (e.g. a slow network response finishing late).
    final notifier = ref.read(_openDevPlanOverlayId.notifier);
    if (notifier.state == widget.course.id) {
      notifier.state = null;
    }
  }

  Future<void> _handleDevPlanAction(BuildContext context, bool isInPlan) async {
    final auth = ref.read(AuthStateNotifier.provider);
    final userId = auth?.user?.id;
    if (userId == null) return;

    setState(() => _isBusy = true);
    final repo = ref.read(DevelopmentPlanActionRepository.provider);

    final result =
        isInPlan
            ? await repo.removeFromDevPlan(courseId: widget.course.id)
            : await repo.addToDevPlan(courseId: widget.course.id);

    if (!mounted) return;
    if (result.success) {
      final membership = ref.read(DevPlanMembershipViewModel.provider.notifier);
      if (isInPlan) {
        membership.markRemoved(widget.course.id);
      } else {
        membership.markInPlan(widget.course.id);
      }
      _closeOverlayIfMine();
      setState(() => _isBusy = false);
      if (context.mounted) {
        Toast.success(
          context,
          isInPlan
              ? 'Course removed from My Development Plan'
              : 'Course added to My Development Plan',
        );
      }
    } else {
      _closeOverlayIfMine();
      setState(() => _isBusy = false);
      if (context.mounted) {
        Toast.error(
          context,
          result.message ?? 'Action failed. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(OfflineViewModel.provider);
    final isManualOffline = ref.watch(OfflineModeNotifier.provider);
    final connectionVM = ref.watch(InternetConnectionProvider.provider);
    ref.watch(SyncViewModel.provider);
    final isOnline = !isManualOffline && connectionVM.isConnected;
    final membership = ref.watch(DevPlanMembershipViewModel.provider);
    final isInPlan = membership.ids.contains(widget.course.id);
    final viewDisabled = isViewCourseDisabled(ref, widget.course.id);
    final showOverlay = ref.watch(_openDevPlanOverlayId) == widget.course.id;

    // CSS ref, confirmed against `origin/staging`'s bluetheme-layout.css:
    // `.course-title` is 1rem (16px) as the page-wide base rule, but a
    // later `@media (max-width: 991px) { .course-title { font-size:
    // 1.05rem !important } }` block (originally written for the Student
    // Dashboard's "Continue Learning" card, but not scoped to it — it's a
    // bare class selector in a globally-loaded stylesheet) beats it below
    // 991px. So it's 16.8px below 991px, 16px at/above it — not a flat
    // 16px everywhere.
    final isWide = MediaQuery.sizeOf(context).width >= 991;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        clipBehavior: Clip.antiAlias,
        // CSS ref: .modern-course-card:hover — transform: translateY(-8px)
        // (a lift, alongside the shadow already applied below).
        transform: Matrix4.translationValues(0, _hovering ? -8 : 0, 0),
        // CSS ref: .modern-course-card — box-shadow is commented out in the
        // reference stylesheet (not applied at rest); a subtle border
        // (rgba(0,0,0,0.03)) is used instead. Kept a hover-only shadow using
        // --card-shadow-hover, since that token is still defined and this
        // class already has a `transition` for it.
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
          boxShadow:
              _hovering
                  ? [
                    BoxShadow(
                      color: const Color(0x1F000000),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ]
                  : null,
        ),
        child: LayoutBuilder(
          builder: (context, cardConstraints) {
            // CSS ref: .card-image-wrapper — padding-top: 56.25% (16:9) of
            // the card's own width. Shared with the image itself (built
            // via `AspectRatio` below) so the confirm overlay — which on
            // the real site lives inside `.card-image-wrapper` and must
            // cover exactly that area — stays in sync with it instead of
            // reverting to the old fixed 180px this used before the image
            // sizing was made fluid.
            final imageHeight = cardConstraints.maxWidth * 9 / 16;
            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // -- Full-width image --------------------------------------
                    // CSS ref: .card-image-wrapper — width: 100%; padding-top:
                    // 56.25% (16:9), i.e. the image height is a fixed FRACTION
                    // of the card's own (fluid) width, not a fixed pixel value —
                    // at >=992px the card itself is `col-lg-3` (25% of a
                    // continuously variable row width), so the correct image
                    // height keeps scaling with the viewport at every width
                    // within a column-count tier, not just switching between a
                    // couple of numbers at the 992/768 breakpoints. `AspectRatio`
                    // reproduces that exactly, deriving height from whatever
                    // width this card actually renders at, rather than a
                    // one-off pixel value measured at a single viewport.
                    // .card-image-wrapper img — object-fit: cover !important.
                    // CSS ref: .card-image-wrapper — border-radius: 12px 12px 0 0
                    // (top corners only; the outer card's own 16px radius is on
                    // all four corners, so the image needs its own tighter clip).
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        // CSS ref: .modern-course-card:hover .card-image-wrapper
                        // img — transform: scale(1.05).
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 200),
                          scale: _hovering ? 1.05 : 1.0,
                          child: _CourseImage(url: widget.course.logo),
                        ),
                      ),
                    ),
                    // -- White content area ------------------------------------
                    // -- White content area � title + button pinned to bottom -
                    // -- White content area: session info, title, rating, btn --
                    Expanded(
                      // CSS ref: .card-body-modern — padding 8px, flex-grow 1
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // CSS ref: .session-info — "NEXT AVAILABLE" label + date
                            if (widget.course.nextSession != null) ...[
                              Text(
                                'NEXT AVAILABLE',
                                style: GoogleFonts.inter(
                                  // CSS ref: .session-info .label — font:500 11px,
                                  // no own line-height, so it inherits `body {
                                  // line-height: 1.5 }` — 16.5px. Flutter's
                                  // default text height (when unset) uses the
                                  // font's own intrinsic metrics, not that
                                  // inherited 1.5, so it has to be set explicitly
                                  // (same as .course-title already does with its
                                  // own explicit 1.4).
                                  color: const Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                  height: 1.5,
                                ),
                              ),
                              // CSS ref: .session-info gap: 2px !important
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  // i.far.fa-calendar-alt: ~10px
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 10,
                                    color: Color(0xFF693D94),
                                  ),
                                  // CSS ref: .session-info .date-display gap: 6px
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _formatNextSession(
                                        widget.course.nextSession!,
                                      ),
                                      style: GoogleFonts.inter(
                                        // CSS ref: .session-info .date-display
                                        // strong — font-weight: 700 (bolder than
                                        // the .date-display container's own 600),
                                        // inherits body's 1.5 line-height same as
                                        // the label above.
                                        color: const Color(0xFF693D94),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        height: 1.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              // CSS ref, confirmed against `origin/staging`'s
                              // modern-course-cards.css: `.session-info`'s own
                              // `margin-bottom: 8px` is commented out
                              // (`/*margin-bottom: 8px !important;*/`) — dead,
                              // not applied — and the winning `.course-title`
                              // margin rule (`margin: 0 0 8px`) explicitly zeros
                              // its own margin-top. So there's genuinely no gap
                              // here on the real site; this SizedBox was citing
                              // a disabled rule as if it were live. Removed —
                              // the `Spacer()` below absorbs the freed space
                              // exactly like the real `.card-actions-modern {
                              // margin-top: auto }` would.
                            ],
                            // CSS ref: .course-title — color var(--card-title)
                            // #1E2939, font-weight 700, padding 0 12px, margin 0
                            // 0 8px (both competing .course-title rules agree on
                            // weight 700 and line-height 1.4; the more specific
                            // one wins font-size 16px/margin 8px/color #1E2939
                            // over the other's 18px/6px/#2D3748). maxLines 2 —
                            // the 172px card-body budget (352 card - 180 image)
                            // fits 2 lines (44.8px) beside the 46px session block
                            // and 41px button; a third line would overflow,
                            // matching the web's -webkit-line-clamp: 2.
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                widget.course.name.isEmpty
                                    ? 'Untitled Course'
                                    : widget.course.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF1E2939),
                                  fontSize: isWide ? 16 : 16.8,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            // CSS ref: .course-title margin-bottom: 8px.
                            const SizedBox(height: 8),
                            // CSS ref: .rating-bar — stars + avg + count
                            if (widget.course.offlineCourse.displayRating ==
                                    1 &&
                                widget.course.offlineCourse.averageRating >
                                    0) ...[
                              // CSS ref: .rating-bar { height: 32px; padding: 4px
                              // 12px; margin: 0 0 2px; border-radius: 8px; onclick:
                              // openreviewsModal(courseId) — applied exactly per
                              // blueprint (no background color is specified, so the
                              // border-radius has no visible effect, but is kept
                              // for fidelity). The explicit 32px height (rather
                              // than letting padding+content decide it) matters:
                              // 4+4 padding + the 18px star icons only sum to
                              // ~26px, 6px short of the real box.
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap:
                                    () => showReviewsModal(
                                      context,
                                      ref,
                                      courseId: widget.course.id,
                                    ),
                                child: Container(
                                  height: 32,
                                  margin: const EdgeInsets.only(bottom: 2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  alignment: Alignment.centerLeft,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: _StarRating(
                                    rating:
                                        widget
                                            .course
                                            .offlineCourse
                                            .averageRating,
                                    count:
                                        widget
                                            .course
                                            .offlineCourse
                                            .ratingCount ??
                                        0,
                                  ),
                                ),
                              ),
                            ],
                            // CSS ref: .card-actions-modern — margin-top: auto
                            // (Spacer below achieves the same push-to-bottom).
                            const Spacer(),
                            // CSS ref: .card-actions-modern — padding: 0 12px 15px.
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 15),
                              child: _ModernViewCourseButton(
                                onPressed:
                                    viewDisabled
                                        ? null
                                        : () => Modular.to.pushNamed(
                                          CoursesModule.construct(
                                            '${CoursesModule.detail}/${widget.course.id}',
                                          ),
                                          arguments:
                                              widget.course.offlineCourse,
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // CSS ref: .dev-plan-action — position: absolute; top: 12px;
                // right: 12px; z-index: 10; computed box 36x36. It sits inside
                // .card-image-wrapper, whose top-right corner is the card's, so
                // card-Stack offsets are identical.
                // Hidden while this card's own confirm overlay is open — the
                // overlay covers the button's spot, and hiding it (rather than
                // just visually covering it) also stops it from being tapped
                // through the frosted blur while the confirm prompt is showing.
                if (membership.loaded && !showOverlay)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _DevPlanButton(
                      isInPlan: isInPlan,
                      onTap:
                          isOnline
                              ? () =>
                                  ref
                                      .read(_openDevPlanOverlayId.notifier)
                                      .state = widget.course.id
                              : null,
                    ),
                  ),
                // Offline save button — top-left. App-specific (no web
                // counterpart); mirrors the dev-plan action's 12px offsets and
                // 36px box (icon 22 + 7px padding each side).
                Positioned(
                  top: 12,
                  left: 12,
                  child: OfflineCourseButton(
                    course: widget.course.offlineCourse,
                    iconSize: 22,
                  ),
                ),
                // Dev plan confirm overlay — div.overlay lives inside
                // .card-image-wrapper on the web, so it covers the image area
                // only, not the whole card. Listed LAST: the web overlay carries
                // z-index: 99 !important, above .dev-plan-action's z-index: 10,
                // so it covers the +/− button while open.
                if (showOverlay)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    // same height as the card image above (.card-image-wrapper)
                    height: imageHeight,
                    child: _DevPlanOverlay(
                      isInPlan: isInPlan,
                      isBusy: _isBusy,
                      onYes: () => _handleDevPlanAction(context, isInPlan),
                      onNo:
                          () =>
                              ref.read(_openDevPlanOverlayId.notifier).state =
                                  null,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _formatNextSession(DateTime dt) {
  // CSS/markup ref, confirmed against `origin/staging`'s
  // _courseCatalogContainer.php: `date("M d, h:i A", $date)` — PHP's `d`
  // is a zero-padded day (01-31), e.g. "May 05, 03:30 PM", not the
  // unpadded "May 5" this rendered before (day was missing its
  // .padLeft, unlike the hour below which already had one).
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
  final hourStr = hour12.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final day = dt.day.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} $day, $hourStr:$minute $ampm';
}

class _DevPlanButton extends StatelessWidget {
  const _DevPlanButton({required this.isInPlan, required this.onTap});
  final bool isInPlan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    // Same accent color for both add (+) and remove (-) states.
    const accentColor = FigmaTokens.primaryPurple;

    // CSS ref: a.plus-icon/.minus-icon title="Add to Development Plan" —
    // the web version's native tooltip on hover.
    return Tooltip(
      message:
          isDisabled
              ? 'Connect to update your development plan'
              : (isInPlan
                  ? 'Remove from Development Plan'
                  : 'Add to Development Plan'),
      child: HoverBuilder(
        builder: (context, hovering) {
          // On hover the button fills solid with its accent color and the
          // icon turns white, matching the web's :hover state (not
          // captured by the static CSS export, so this mirrors the
          // reference screenshot directly).
          final filled = !isDisabled && hovering;
          return MouseRegion(
            cursor:
                isDisabled
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              // CSS ref: .plus-icon:hover/.minus-icon:hover — also
              // transform: scale(1.1), not just the color fill.
              child: AnimatedScale(
                duration: const Duration(milliseconds: 150),
                scale: filled ? 1.1 : 1.0,
                child: ClipOval(
                  // CSS ref: .dev-plan-action .plus-icon — backdrop-filter:
                  // blur(4px), on top of the 90%-opacity white fill.
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      // CSS ref: .dev-plan-action computed box — 36x36.
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        // CSS ref: .dev-plan-action .plus-icon — background
                        // rgba(255,255,255,0.9), box-shadow 0 4px 12px rgba(0,0,0,0.1).
                        color:
                            isDisabled
                                ? Colors.white
                                : (filled
                                    ? accentColor
                                    : Colors.white.withValues(alpha: 0.9)),
                        // CSS ref: .dev-plan-action .plus-icon / .minus-icon —
                        // border-radius: 50% (full circle on the 36x36 box).
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      // CSS ref, confirmed against the live rendered app:
                      // Icons.add_rounded/remove_rounded render as a wrong
                      // glyph here (looks like an unrelated bookmark-ribbon
                      // shape, not a plus/minus) — a known Flutter web issue
                      // with certain `_rounded`-suffixed icons after the
                      // Material Symbols font migration. The plain
                      // (non-rounded) variants use the older, stable
                      // codepoints and render correctly.
                      child: Icon(
                        isDisabled
                            ? Icons.cloud_off
                            : (isInPlan ? Icons.remove : Icons.add),
                        // Icon scales with the 36px box (was 18 on the old 30px box).
                        size: isDisabled ? 18 : 22,
                        // `weight` is a variable Material Symbols font
                        // property; passing it alongside the classic
                        // (non-Symbols) `Icons` constants used here was
                        // producing a wrong/unrelated glyph (looked like a
                        // bookmark ribbon, not a plus/minus) — confirmed via
                        // live render, unaffected by which Icons.* constant
                        // was used. Dropped.
                        color:
                            isDisabled
                                ? _catalogMuted
                                : (filled ? Colors.white : accentColor),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DevPlanOverlay extends StatelessWidget {
  const _DevPlanOverlay({
    required this.isInPlan,
    required this.isBusy,
    required this.onYes,
    required this.onNo,
  });
  final bool isInPlan;
  final bool isBusy;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    final action = isInPlan ? 'Remove' : 'Add';
    final prep = isInPlan ? 'from' : 'to';
    // CSS ref: .overlay — hidden state is opacity: 0 / scale(1.1); the
    // shown state fades to opacity 1 and settles at scale(1) over 0.4s
    // cubic-bezier(0.16, 1, 0.3, 1). TweenAnimationBuilder replays that
    // entrance every time the overlay is inserted.
    //
    // ClipRect+BackdropFilter are kept OUTSIDE the scale animation and
    // fixed to the full 180px box: scaling them together with the content
    // (as before) meant the whole clipped region briefly grew ~10% larger
    // than the box during the entrance, which could poke past the card's
    // own rounded-corner clip and chop the top line of text. With the
    // clip fixed, only the inner Column scales/fades, safely within it.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        // CSS ref, confirmed against `origin/staging`'s
        // modern-course-cards.css: .overlay — padding: 15px !important;
        // flex column centered; text-align: center; color: #fff
        // !important; `backdrop-filter: blur(8px)` — and genuinely no
        // background-color property at all (not even a commented-out
        // one). Blur-only, no scrim, exactly as the real site has it —
        // a previous grey scrim here for "practical legibility" was a
        // deliberate deviation, removed to match exactly.
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(15),
          // Defensive: clip the animated content to the padded box too, so
          // even at the animation's largest scale (1.1x) nothing can ever
          // paint outside this card's image area, regardless of content
          // height at a given card width.
          child: ClipRect(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 400),
              curve: const Cubic(0.16, 1, 0.3, 1),
              builder:
                  (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.scale(scale: 1.1 - 0.1 * t, child: child),
                  ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // CSS ref: .overlay p — font-size 15px, margin 0 24px
                  // 25px (a 24px horizontal inset beyond the overlay's own
                  // 15px padding, plus a 25px gap before the buttons).
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '$action this course $prep your development plan?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  if (isBusy)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _OverlayBtn(label: 'YES', onTap: onYes, filled: true),
                        const SizedBox(width: 10),
                        _OverlayBtn(label: 'NO', onTap: onNo, filled: false),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayBtn extends StatelessWidget {
  const _OverlayBtn({
    required this.label,
    required this.onTap,
    required this.filled,
  });
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    // CSS ref: .overlay_btn — both Yes and No share the same style: bg
    // #fff, color #693D94, padding 8px 20px, border-radius 12px, box-shadow
    // 0 4px 10px rgba(0,0,0,0.2), font 700 13px/19.5px. There is no
    // filled/outline distinction on the web for this class at rest.
    //
    // The web's :hover state isn't in the static CSS export, so this dark
    // fill (bg + white text) is matched from a screenshot of the live
    // hover state — applied identically to both Yes and No.
    //
    // CSS ref, confirmed against `origin/staging`'s catalogue.php own
    // inline <style>: below 767px its `@media` block redeclares
    // `.overlay_btn { background: #693D94 !important; color: #fff !important }`
    // / `:hover { background: #4345a3 !important }` — a BARE selector, not
    // scoped to the (otherwise dead on this page) `.team-item` card, so it
    // genuinely applies to this button too. Since both this rule and
    // modern-course-cards.css's competing one use `!important` with equal
    // specificity, source order decides — catalogue.php's inline block
    // renders later in the DOM, so it wins for exactly these two
    // properties (radius/shadow/weight/padding stay the modern values,
    // which remain `!important` and uncontested here).
    final narrow = MediaQuery.sizeOf(context).width <= 767;
    return HoverBuilder(
      builder:
          (context, hovering) => MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                // CSS ref: .overlay_btn:hover also lifts translateY(-2px) and
                // escalates the shadow to 0 6px 15px rgba(0,0,0,.3) (from the
                // resting 0 4px 10px rgba(0,0,0,.2)) — not just the color swap.
                transform: Matrix4.translationValues(0, hovering ? -2 : 0, 0),
                decoration: BoxDecoration(
                  color:
                      narrow
                          ? (hovering
                              ? const Color(0xFF4345A3)
                              : _catalogPurple)
                          : (hovering ? _catalogInk : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, hovering ? 0.3 : 0.2),
                      blurRadius: hovering ? 15 : 10,
                      offset: Offset(0, hovering ? 6 : 4),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color:
                        narrow
                            ? Colors.white
                            : (hovering ? Colors.white : _catalogPurple),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    // CSS ref: .overlay_btn letter-spacing: 0.5px (was 0.4).
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

class _CourseImage extends ConsumerWidget {
  const _CourseImage({this.url});
  final String? url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The real fallback (`/dist/images/course-bg.svg`) can never actually
    // render in this app — see `CourseImageFallback`'s own doc comment —
    // so a real local placeholder is used instead of a broken network
    // fetch that always ends up blank. Also used as the `errorBuilder`
    // below when the course's own logo URL fails to load.
    const fallback = CourseImageFallback();
    if (url == null) return fallback;
    return Image.network(
      devProxiedImageUrl(url!),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder:
          (context, child, progress) =>
              progress == null
                  ? child
                  : Container(
                    color: const Color(0xFFF1EFFB),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _catalogPurple,
                    ),
                  ),
    );
  }
}

// ── Modern filled View Course button ─────────────────────────────────────────
// CSS ref: .btn-modern-primary — bg-[#693D94] hover:bg-[#5a3480] text-white
//          rounded-[8px] full-width font-weight:600 font-size:13px

class _ModernViewCourseButton extends StatefulWidget {
  const _ModernViewCourseButton({this.onPressed});
  final VoidCallback? onPressed;

  @override
  State<_ModernViewCourseButton> createState() =>
      _ModernViewCourseButtonState();
}

class _ModernViewCourseButtonState extends State<_ModernViewCourseButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 41, // a.btn-modern-primary: height 41px
          alignment: Alignment.center,
          // CSS ref, confirmed against live computed style: default state
          // has `box-shadow: none` — the shadow only appears on
          // `:hover` (`0 4px 12px rgba(84,87,193,.3)`), alongside a
          // `translateY(-2px)` lift. Previous code had this backwards
          // (shadow shown by default, removed on hover, no lift at all).
          transform: Matrix4.translationValues(0, _hovering ? -2 : 0, 0),
          decoration: BoxDecoration(
            color:
                disabled
                    ? const Color(0xFF693D94).withValues(alpha: 0.4)
                    : _hovering
                    ? const Color(0xFF5A3480)
                    : const Color(0xFF693D94),
            // CSS ref: .btn-modern-primary border-radius: 12px (was 8).
            borderRadius: BorderRadius.circular(12),
            boxShadow:
                !disabled && _hovering
                    ? const [
                      BoxShadow(
                        color: Color.fromRGBO(84, 87, 193, 0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                    : null,
          ),
          child: Text(
            'View Course',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14, // a.btn-modern-primary: font 14px
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Star rating row ────────────────────────────────────────────────────────────
// CSS ref: .rating-bar — stars (filled/half/empty) + average + (count)

class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    // CSS ref, confirmed against `origin/staging`'s modern-course-cards
    // .css: .rating-stars — color #FFD700, font-size 18px, letter-spacing
    // 1px (a small gap between the star glyphs) — was wrongly #FFA534
    // with no gap. .average-rating — font 700 15px, color var(--text-main)
    // = #1E293B — was wrongly #2D3748 (the Student Dashboard's own
    // card-title color, not this one). .review-count — color
    // var(--text-muted) = #64748B, font-size 13px (already correct).
    // (The rating-bar's own 4px/12px padding / 2px margin / 8px radius /
    // 32px height are applied by the Container wrapping this widget in
    // _CatalogCourseCard, not inside this widget itself.)
    return Row(
      children: [
        ...List.generate(5, (i) {
          final filled = rating >= i + 1;
          final half = !filled && rating >= i + 0.5;
          return Padding(
            padding: EdgeInsets.only(right: i < 4 ? 1 : 0),
            child: Icon(
              filled
                  ? Icons.star_rounded
                  : half
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
              size: 18,
              color: const Color(0xFFFFD700),
            ),
          );
        }),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.inter(
            color: const Color(0xFF1E293B),
            fontSize: 15,
            fontWeight: FontWeight.w700,
            // CSS ref: .average-rating has no own line-height, inherits
            // body's 1.5.
            height: 1.5,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 2),
          Text(
            '($count)',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 13,
              // CSS ref: .review-count — same, inherits body's 1.5.
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: _catalogMuted, size: 54),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (onRetry != null)
            RetryButton(onRetry: onRetry!, errorMessage: message),
        ],
      ),
    ),
  );
}

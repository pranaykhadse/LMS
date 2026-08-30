import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';

const _purple = FigmaTokens.primaryPurple;
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;

class PaginationWidget extends StatelessWidget {
  const PaginationWidget({
    super.key,
    required this.page,
    required this.pages,
    required this.onPage,
    this.showProgressBar = false,
  });

  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  /// CSS ref: .pagination-footer / .pg-progress-container / .pg-progress-bar
  /// / .pg-status-text — a thin proportional progress track + "Page X of Y"
  /// text, shown below the numbered page row. Opt-in (defaults to false) so
  /// existing call sites of this shared widget (dashboard course lists,
  /// item inventory, development plan, etc.) keep their current appearance
  /// unless they explicitly ask for the extra footer.
  final bool showProgressBar;

  @override
  Widget build(BuildContext context) {
    if (pages <= 1) return const SizedBox.shrink();

    final nums = _pageNumbers(page, pages);
    final progress = page / pages;
    // CSS ref, confirmed against `origin/staging`'s bluetheme-layout.css:
    // `@media (max-width: 575px)` shrinks `.pagination` padding (20px 30px
    // -> 15px all), its gap (12px -> 8px), and the numbered `.page-link`
    // boxes (42px/14px -> 36px/12px) — the prev/next circular arrows stay
    // 44px at every width, since `.page-item.prev/.next .page-link` is a
    // more specific selector than the bare `.page-link` this media query
    // overrides, so it wins regardless of the media query.
    final narrow = MediaQuery.sizeOf(context).width <= 575;
    final linkSize = narrow ? 36.0 : 42.0;
    final linkFontSize = narrow ? 12.0 : 14.0;
    final rowGap = narrow ? 8.0 : 12.0;

    // CSS ref: .pagination — gap: 12px between every item (nav buttons,
    // numbers, ellipsis alike). Built as a flat list so a uniform 12px
    // SizedBox can be interspersed between items, replacing the previous
    // ad hoc per-item margin/padding (3px/4px/6px, inconsistent).
    final items = <Widget>[
      _NavBtn(
        icon: Icons.chevron_left,
        onTap: page > 1 ? () => onPage(page - 1) : null,
      ),
      ...nums.map((p) {
        if (p == -1) {
          return Text(
            // li.disabled.ellipsis-end renders a plain "..."
            // (span.page-link with border:none) — so it inherits
            // .page-link's own color/weight/font-size (#64748b/600/14px,
            // 12px <=575px), not a generic app-muted color/weight. Was
            // using `_muted` (#6A7282, a different app-wide gray token)
            // at a flat weight-500/14px regardless of width.
            '...',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: linkFontSize,
              fontWeight: FontWeight.w600,
            ),
          );
        }
        final isCurrent = p == page;
        // CSS ref: .page-item.active .page-link — also transform:
        // translateY(-2px) (a lift, on top of the fill/border/shadow
        // already applied below). .page-link:hover:not(.active) —
        // transform: translateY(-1px), background #f8fafc, border-color
        // #e2e8f0, color var(--primary-color).
        return HoverBuilder(
          cursor:
              isCurrent ? SystemMouseCursors.basic : SystemMouseCursors.click,
          builder:
              (context, hovering) => GestureDetector(
                onTap: isCurrent ? null : () => onPage(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: linkSize,
                  height: linkSize,
                  alignment: Alignment.center,
                  transform: Matrix4.translationValues(
                    0,
                    isCurrent ? -2 : (hovering ? -1 : 0),
                    0,
                  ),
                  decoration: BoxDecoration(
                    // CSS ref (active .page-link inline style):
                    // background-color #693D94, border-color
                    // #693D94, color #fff, box-shadow
                    // 0 8px 16px rgba(105, 61, 148, 0.25)
                    color:
                        isCurrent
                            ? _purple
                            : (hovering
                                ? const Color(0xFFF8FAFC)
                                : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isCurrent
                              ? _purple
                              : (hovering
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFFF1F5F9)),
                    ),
                    boxShadow:
                        isCurrent
                            ? [
                              BoxShadow(
                                color: _purple.withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ]
                            : null,
                  ),
                  child: Text(
                    '$p',
                    style: GoogleFonts.inter(
                      color:
                          isCurrent
                              ? Colors.white
                              : (hovering ? _purple : _ink),
                      fontWeight: FontWeight.w600,
                      fontSize: linkFontSize,
                    ),
                  ),
                ),
              ),
        );
      }),
      _NavBtn(
        icon: Icons.chevron_right,
        onTap: page < pages ? () => onPage(page + 1) : null,
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Centered row + progress bar at same width ──────────────────
        Center(
          child: IntrinsicWidth(
            child: Container(
              // CSS ref: .pagination — background: #fff; padding: 20px
              // 30px (15px all <=575px); border-radius: 24px.
              padding:
                  narrow
                      ? const EdgeInsets.all(15)
                      : const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 20,
                      ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Page buttons row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) SizedBox(width: rowGap),
                          items[i],
                        ],
                      ],
                    ),
                  ),
                  if (showProgressBar) ...[
                    // CSS ref: .pagination-footer — margin: 5px 0 0; display:
                    // flex column, centered, gap 12px. .pg-progress-container:
                    // a literal 200x4, bg #F1F5F9, radius 10. .pg-progress-bar
                    // (fill): bg #693D94, radius 10, width = (page / pages) *
                    // 200 (a literal pixel width, not a container-relative
                    // percentage). .pg-status-text: "Page X of Y", color
                    // #94A3B8, font weight 800, size 12, line-height 18px.
                    //
                    // Built with fixed pixel widths rather than
                    // FractionallySizedBox — that widget can't report proper
                    // intrinsic dimensions, and this whole footer sits inside
                    // an IntrinsicWidth (below) to shrink-wrap + center the
                    // pager, so the combination broke layout.
                    const SizedBox(height: 20),
                    Center(
                      // CSS ref: .pg-progress-container — width 200px,
                      // 150px at <=575px (no explicit override in the
                      // stylesheet, but this footer's other pieces all
                      // shrink under the same media query — kept
                      // proportionally consistent).
                      child: Container(
                        width: narrow ? 150 : 200,
                        height: 4,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width:
                                (narrow ? 150 : 200) * progress.clamp(0.0, 1.0),
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFF693D94),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        // Rendered uppercase on the web (visually confirmed
                        // against a screenshot — "PAGE 1 OF 10", not "Page 1
                        // of 10"); Flutter has no CSS text-transform
                        // equivalent, so the string itself is upper-cased.
                        'Page $page of $pages'.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          height: 18 / 12,
                          // CSS ref: .pg-status-text letter-spacing: 1px.
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    // Progress bar — same width as the row above
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: AlwaysStoppedAnimation<Color>(_purple),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // PAGE X OF Y
                    Center(
                      child: Text(
                        'PAGE $page OF $pages',
                        style: GoogleFonts.inter(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Behavior ref, confirmed against `origin/staging`'s
  /// backend/views/layouts/bluetheme_layout.php — a "Premium Pagination
  /// Reconstruction" script that runs on EVERY `.pagination` element on
  /// EVERY page (applied globally via the shared layout, independent of
  /// whatever the raw server-rendered `LinkPager` HTML looked like).
  /// Its visibility rule, verbatim:
  ///   pageNum === 1 || pageNum === totalPages ||
  ///     Math.abs(pageNum - currentPage) <= 2
  /// i.e. always show the first and last page, plus a 5-page window
  /// centered on the current page (current-2 … current+2) — not the
  /// 3-page window this previously implemented. A single "…" is spliced
  /// in wherever a contiguous run of hidden pages sits between two shown
  /// ones (the JS only ever inserts one ellipsis-start / one
  /// ellipsis-end per pagination instance, via its "already exists?"
  /// check — reproduced here by only adding a `-1` marker once per gap).
  static List<int> _pageNumbers(int current, int total) {
    if (total <= 1) return [1];
    final result = <int>[];
    var ellipsisPending = false;
    for (var p = 1; p <= total; p++) {
      final show = p == 1 || p == total || (p - current).abs() <= 2;
      if (show) {
        result.add(p);
        ellipsisPending = false;
      } else if (!ellipsisPending) {
        result.add(-1);
        ellipsisPending = true;
      }
    }
    return result;
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    // CSS ref: .page-item.prev/.next .page-link:hover — background
    // #f1f5f9, color var(--primary-color).
    //
    // Disabled state per explicit user request: when there's no prev/
    // next page, this button is dimmed (opacity 0.4) and ignores hover
    // entirely — previously `onTap` was already null at the boundary
    // (so it never actually navigated), but the button still lit up
    // fully on hover (background/color/lift) as if it were clickable,
    // which read as misleadingly active. Note: the real web page's own
    // "Premium Pagination Reconstruction" JS never actually disables
    // this button at all (a boundary click just re-navigates to the
    // same page, no-op) — this dimmed/inert treatment is a deliberate
    // deviation from that, per the user's explicit request.
    return HoverBuilder(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder: (context, hovering) {
        final active = hovering && !disabled;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: disabled ? 0.4 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              transform: Matrix4.translationValues(0, active ? -1 : 0, 0),
              // CSS ref: .page-item.prev .page-link, .page-item.next .page-link
              // — width/height 44px, border-radius 50% (full circle), background
              // #f8fafc, no border, color #475569. Distinct chrome from the
              // numbered page-links (bordered box, white bg, radius 12).
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    active ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              // Enlarged per request (was 14, matching the CSS's computed
              // 8.75x14 glyph box). Note: Icons.chevron_left/_right come from
              // the classic fixed-weight Icons font (same constraint hit
              // earlier on the dev-plan +/- icon) — there's no weight
              // parameter that visibly bolds it, so only size increased here.
              child: Icon(
                icon,
                size: 26,
                color: active ? _purple : const Color(0xFF475569),
              ),
            ),
          ),
        );
      },
    );
  }
}

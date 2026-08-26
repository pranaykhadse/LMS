import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';

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
            // (span.page-link with border:none)
            '...',
            style: GoogleFonts.inter(
              color: _muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          );
        }
        final isCurrent = p == page;
        return GestureDetector(
          onTap: isCurrent ? null : () => onPage(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // CSS ref (active .page-link inline style):
              // background-color #693D94, border-color
              // #693D94, color #fff, box-shadow
              // 0 8px 16px rgba(105, 61, 148, 0.25)
              color: isCurrent ? _purple : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrent ? _purple : const Color(0xFFE5E7EB),
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
                color: isCurrent ? Colors.white : _ink,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                fontSize: 16,
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
              // 30px; border-radius: 24px.
              padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 28),
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
                          if (i > 0) const SizedBox(width: 24),
                          items[i],
                        ],
                      ],
                    ),
                  ),
                  if (showProgressBar) ...[
                    // CSS ref: .pagination-footer — margin: 5px 0 0; display:
                    // flex column, centered. .pg-progress-container: 200x4,
                    // bg #F1F5F9, radius 10. .pg-progress-bar (fill): bg
                    // #693D94, radius 10, width = (page / pages) * track
                    // width (proportional, not a literal pixel value).
                    // .pg-status-text: "Page X of Y", color #94A3B8, font
                    // weight 800, size 12, line-height 18px.
                    const SizedBox(height: 20),
                    // Track is half the row's width and centered, rather
                    // than stretching full-width under the Column's
                    // crossAxisAlignment.stretch.
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 4,
                            child: Stack(
                              children: [
                                Container(color: const Color(0xFFF1F5F9)),
                                FractionallySizedBox(
                                  widthFactor: progress.clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF693D94),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
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
                          letterSpacing: 0.8,
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

  /// CSS ref: the web pager keeps the first page, a 3-page window around
  /// the current page and the last page visible, hiding everything else
  /// behind "..." — page 1 of 10 renders as: 1 2 3 ... 10.
  static List<int> _pageNumbers(int current, int total) {
    if (total <= 5) return List.generate(total, (i) => i + 1);
    final start = (current - 1).clamp(1, total - 2);
    final end = (start + 2).clamp(start, total);
    final result = <int>[1];
    if (start > 2) result.add(-1);
    for (int p = start; p <= end; p++) {
      if (p != 1 && p != total) result.add(p);
    }
    if (end < total - 1) result.add(-1);
    result.add(total);
    return result;
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // CSS ref: .page-item.prev .page-link, .page-item.next .page-link
        // — width/height 44px, border-radius 50% (full circle), background
        // #f8fafc, no border, color #475569. Distinct chrome from the
        // numbered page-links (bordered box, white bg, radius 12).
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          shape: BoxShape.circle,
        ),
        // Enlarged per request (was 14, matching the CSS's computed
        // 8.75x14 glyph box). Note: Icons.chevron_left/_right come from
        // the classic fixed-weight Icons font (same constraint hit
        // earlier on the dev-plan +/- icon) — there's no weight
        // parameter that visibly bolds it, so only size increased here.
        child: Icon(icon, size: 26, color: const Color(0xFF475569)),
      ),
    );
  }
}

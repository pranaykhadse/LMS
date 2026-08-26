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
  });

  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (pages <= 1) return const SizedBox.shrink();

    final nums = _pageNumbers(page, pages);
    final progress = page / pages;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Centered row + progress bar at same width ──────────────────
        Center(
          child: IntrinsicWidth(
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
                      _NavBtn(
                        icon: Icons.chevron_left,
                        onTap: page > 1 ? () => onPage(page - 1) : null,
                      ),
                      const SizedBox(width: 4),
                      ...nums.map((p) {
                        if (p == -1) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              // li.disabled.ellipsis-end renders a plain
                              // "..." (span.page-link with border:none)
                              '...',
                              style: GoogleFonts.inter(
                                color: _muted,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        final isCurrent = p == page;
                        return GestureDetector(
                          onTap: isCurrent ? null : () => onPage(p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin:
                                const EdgeInsets.symmetric(horizontal: 3),
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              // CSS ref (active .page-link inline style):
                              // background-color #693D94, border-color
                              // #693D94, color #fff, box-shadow
                              // 0 8px 16px rgba(105, 61, 148, 0.25)
                              color:
                                  isCurrent ? _purple : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCurrent
                                    ? _purple
                                    : const Color(0xFFE5E7EB),
                              ),
                              boxShadow: isCurrent
                                  ? [
                                      BoxShadow(
                                        color: _purple
                                            .withValues(alpha: 0.25),
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
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 4),
                      _NavBtn(
                        icon: Icons.chevron_right,
                        onTap: page < pages ? () => onPage(page + 1) : null,
                      ),
                    ],
                  ),
                ),
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
                const SizedBox(height: 12),
              ],
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
  const _NavBtn({
    required this.icon,
    this.onTap,
  });
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        // CSS ref: li.page-item.prev/.next — the chevron page-links share
        // the number links' bordered box chrome and never carry .disabled.
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: _ink,
        ),
      ),
    );
  }
}

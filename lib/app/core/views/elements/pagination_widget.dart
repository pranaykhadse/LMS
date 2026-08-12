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
                        enabled: page > 1,
                        onTap: () => onPage(page - 1),
                      ),
                      const SizedBox(width: 4),
                      ...nums.map((p) {
                        if (p == -1) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '…',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 15,
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
                              color:
                                  isCurrent ? _purple : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: isCurrent
                                  ? null
                                  : Border.all(
                                      color: const Color(0xFFE5E7EB)),
                              boxShadow: isCurrent
                                  ? [
                                      BoxShadow(
                                        color: _purple
                                            .withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              '$p',
                              style: GoogleFonts.roboto(
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
                        enabled: page < pages,
                        onTap: () => onPage(page + 1),
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
                    style: GoogleFonts.roboto(
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

  static List<int> _pageNumbers(int current, int total) {
    if (total <= 7) return List.generate(total, (i) => i + 1);
    final left = (current - 2).clamp(2, (total - 5).clamp(2, total));
    final right = (left + 4).clamp(left, total - 1);
    final result = <int>[1];
    if (left > 2) result.add(-1);
    for (int p = left; p <= right; p++) result.add(p);
    if (right < total - 1) result.add(-1);
    if (result.last != total) result.add(total);
    return result;
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? const Color(0xFFE5E7EB)
                : const Color(0xFFF3F4F6),
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? _ink : const Color(0xFFD1D5DB),
        ),
      ),
    );
  }
}

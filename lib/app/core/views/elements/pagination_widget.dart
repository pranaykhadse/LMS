import 'package:flutter/material.dart';

const _purple = Color(0xFF693D94);
const _ink = Color(0xFF172033);
const _muted = Color(0xFF7C879D);

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

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PagBtn(
              icon: Icons.chevron_left,
              enabled: page > 1,
              onTap: () => onPage(page - 1),
            ),
            const SizedBox(width: 4),
            ...nums.map((p) {
              if (p == -1) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('...', style: TextStyle(color: _muted, fontSize: 14)),
                );
              }
              final isCurrent = p == page;
              return GestureDetector(
                onTap: isCurrent ? null : () => onPage(p),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCurrent ? _purple : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isCurrent
                        ? null
                        : Border.all(color: const Color(0xFFDDE2EA)),
                  ),
                  child: Text(
                    '$p',
                    style: TextStyle(
                      color: isCurrent ? Colors.white : _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 4),
            _PagBtn(
              icon: Icons.chevron_right,
              enabled: page < pages,
              onTap: () => onPage(page + 1),
            ),
          ],
        ),
      ),
    );
  }

  static List<int> _pageNumbers(int current, int total) {
    if (total <= 7) return List.generate(total, (i) => i + 1);
    // 5-page sliding window: always show first + window[current-2..current+2] + last
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

class _PagBtn extends StatelessWidget {
  const _PagBtn({
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
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? const Color(0xFFDDE2EA) : const Color(0xFFEEF1F6),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? _ink : _muted,
        ),
      ),
    );
  }
}

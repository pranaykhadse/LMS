import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/navigation/root_navigator.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/features/courses/repository/reviews_repository.dart';

const _purple = FigmaTokens.primaryPurple;
// CSS ref: .rw-summary-stars / .rw-stars — color #f59e0b (amber), not this
// app's usual purple accent.
const _starAmber = Color(0xFFF59E0B);

/// Opens the site's course-reviews modal for [courseId].
///
/// `GET lms-screen/review-modal?course_id=<id>` is the Bearer-token-authed
/// REST equivalent of the web app's cookie-session `course/load-reviews`
/// route (its `openreviewsModal()` calls the latter directly). Both return
/// the same static, server-rendered HTML fragment
/// (`_course_reviews.php` — `.rw-summary` + `.rw-card` list, or
/// `.rw-empty`) under `payload.reviews_html` — parsed here via regex
/// rather than a full HTML parser, since the shape is a fixed template,
/// not arbitrary markup.
void showReviewsModal(
  BuildContext context,
  WidgetRef ref, {
  required int courseId,
}) {
  showDialog<void>(
    // `/home` is a nested flutter_modular child module (see
    // root_navigator.dart), so the default `useRootNavigator: true`
    // lookup from a context inside it can't reach the app's true
    // outermost Navigator — the barrier ended up sized to that module's
    // own routed viewport, leaving the persistent header/nav bar outside
    // it undimmed (confirmed via a live screenshot). Anchoring on the
    // root navigator's own context sidesteps that module boundary
    // entirely, so the given [context] is only used as a fallback for
    // the (practically impossible) case where the root key isn't
    // attached yet.
    context: rootNavigatorKey.currentContext ?? context,
    // CSS ref: this is a plain Bootstrap `.modal.fade.show`, whose backdrop
    // is the generic `.modal-backdrop` (background rgb(0,0,0)) +
    // `.modal-backdrop.show { opacity: .5 }` — solid black at 50%. (The
    // `.backdrop { rgba(15,21,32,.7) }` rule elsewhere in the stylesheet is
    // a different custom class used by the slide-in `.right .modal`
    // drawers, not this modal — confirmed against a live capture of the
    // actual `#reviews_modal` markup.)
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => _ReviewsDialog(courseId: courseId),
  );
}

class _ReviewsData {
  const _ReviewsData({
    required this.score,
    required this.countLabel,
    required this.items,
  });
  final double score;
  final String countLabel;
  final List<_ReviewItem> items;
}

class _ReviewItem {
  const _ReviewItem({
    required this.initial,
    required this.name,
    required this.date,
    required this.rating,
    required this.comment,
  });
  final String initial;
  final String name;
  final String date;
  final double rating;
  final String comment;
}

/// Matches `_course_reviews.php`'s fixed template shape via regex — the
/// summary block always renders (even at 0 reviews), followed by either
/// the `.rw-card` list or the `.rw-empty` state.
_ReviewsData _parseReviewsHtml(String html) {
  final score =
      double.tryParse(
        RegExp(
              r'rw-summary-score">([^<]*)',
            ).firstMatch(html)?.group(1)?.trim() ??
            '',
      ) ??
      0.0;
  final label =
      RegExp(r'rw-summary-label">([^<]*)').firstMatch(html)?.group(1)?.trim() ??
      '';

  final items = <_ReviewItem>[];
  final cardChunks = html.split('<div class="rw-card">')..removeAt(0);
  for (final chunk in cardChunks) {
    final initial =
        RegExp(r'rw-avatar">([^<]*)').firstMatch(chunk)?.group(1)?.trim() ?? '';
    final name =
        RegExp(r'rw-name">([^<]*)').firstMatch(chunk)?.group(1)?.trim() ?? '';
    final date =
        RegExp(r'rw-date">([^<]*)').firstMatch(chunk)?.group(1)?.trim() ?? '';
    final fullStars = RegExp(r'class="fas fa-star"').allMatches(chunk).length;
    final halfStars =
        RegExp(r'class="fas fa-star-half-alt"').allMatches(chunk).length;
    final comment =
        RegExp(
          r'rw-comment">([\s\S]*?)</div>',
        ).firstMatch(chunk)?.group(1)?.trim() ??
        '';
    items.add(
      _ReviewItem(
        initial: _decodeHtmlEntities(initial),
        name: _decodeHtmlEntities(name),
        date: date,
        rating: fullStars + halfStars * 0.5,
        comment: _decodeHtmlEntities(comment),
      ),
    );
  }
  return _ReviewsData(score: score, countLabel: label, items: items);
}

/// Un-escapes the entities `Html::encode()` produces server-side
/// (`&`, `<`, `>`, `"`, `'`) plus numeric entities, so review names/
/// comments containing those characters display correctly instead of
/// literally.
String _decodeHtmlEntities(String value) {
  return value
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!)),
      )
      .replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
      )
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'");
}

class _ReviewsDialog extends ConsumerStatefulWidget {
  const _ReviewsDialog({required this.courseId});
  final int courseId;

  @override
  ConsumerState<_ReviewsDialog> createState() => _ReviewsDialogState();
}

class _ReviewsDialogState extends ConsumerState<_ReviewsDialog> {
  bool _loading = true;
  String? _error;
  _ReviewsData? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final html = await ref
          .read(ReviewsRepository.provider)
          .fetchReviewsHtml(widget.courseId);
      final data = _parseReviewsHtml(html);
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load reviews.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          // Bootstrap's .modal-lg — ~800px cap.
          constraints: const BoxConstraints(maxWidth: 800),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // CSS ref: .modal-content--reviews — border-radius 16px,
              // box-shadow 0 20px 60px rgba(0,0,0,.15).
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 60,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                // CSS ref: .modal-body--reviews — max-height: 75vh;
                // overflow-y: auto. This shrinks to fit its content and
                // only caps (with a scrollbar) once content overflows —
                // NOT a fixed height — so a `ConstrainedBox` (upper bound
                // only), not a forced `SizedBox`, matches the real modal.
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  // CSS ref: .modal-body--reviews — padding 32px 28px 28px.
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                    child: _buildBody(),
                  ),
                ),
              ),
              // CSS ref: .reviews-close-btn — position absolute top16
              // right16 z10, 32x32, bg rgba(0,0,0,.05), radius 50%, color
              // #9ca3af, font-size 14px; hover: bg rgba(0,0,0,.1),
              // color #374151.
              Positioned(
                top: 16,
                right: 16,
                child: _CloseButton(onTap: () => Navigator.of(context).pop()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();
    final data = _data;
    if (data == null) return _buildEmptyState();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SummaryRow(summary: data),
        // CSS ref: .rw-divider — height 1px, bg #F3F4F6, margin-bottom 20.
        Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 20),
          color: const Color(0xFFF3F4F6),
        ),
        if (data.items.isEmpty)
          _buildEmptyState()
        else
          for (var i = 0; i < data.items.length; i++)
            _ReviewCard(
              item: data.items[i],
              isLast: i == data.items.length - 1,
            ),
      ],
    );
  }

  // CSS ref: .reviews-loading — column, gap 12, padding 60px 0, color
  // #9CA3AF, 14px. .reviews-spinner — 28x28, 3px ring, spins.
  Widget _buildLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3, color: _purple),
            ),
            SizedBox(height: 12),
            Text(
              'Loading reviews...',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: Color(0xFFD1D5DB),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unable to load reviews.',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _fetch, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  // CSS ref: .rw-empty — column, centered, gap 8px, padding 48px 0, color
  // #9CA3AF, 14px; icon (`fa-comment-dots`) 36px color #D1D5DB.
  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 36,
              color: Color(0xFFD1D5DB),
            ),
            SizedBox(height: 8),
            Text(
              'No reviews yet. Be the first to share your feedback!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary row ──────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});
  final _ReviewsData summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // CSS ref: .rw-summary-score — 40px/800, color #111827.
        Text(
          summary.score.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
            height: 1,
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // CSS ref: .rw-summary-stars — color #F59E0B, 18px.
            _StarRow(rating: summary.score, size: 18),
            const SizedBox(height: 2),
            // CSS ref: .rw-summary-label — 13px, color #6B7280.
            Text(
              summary.countLabel,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, required this.size});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        if (i < rating.floor()) {
          icon = Icons.star_rounded;
        } else if (i < rating) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(icon, color: _starAmber, size: size);
      }),
    );
  }
}

// ── Review card ───────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.item, required this.isLast});
  final _ReviewItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    // CSS ref: .rw-card — flex row, gap 12px, padding 14px 0, border-
    // bottom 1px solid #F3F4F6 (none on :last-child).
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border:
            isLast
                ? null
                : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CSS ref: .rw-avatar — 36x36 circle, gradient #693D94 ->
          // #AA399F, white 14px/700 initial.
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF693D94), Color(0xFFAA399F)],
              ),
            ),
            child: Text(
              item.initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CSS ref: .rw-card-head — row, space-between, gap 8px,
                // margin-bottom 2px. .rw-name — 14px, #111827. .rw-date —
                // 11px, #9CA3AF.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.date,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // CSS ref: .rw-stars — 11px, color #F59E0B.
                _StarRow(rating: item.rating, size: 11),
                if (item.comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  // CSS ref: .rw-comment — 14px, color #4B5563, line-
                  // height 1.5.
                  Text(
                    item.comment,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4B5563),
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder:
          (context, hovering) => InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: hovering ? 0.1 : 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color:
                    hovering
                        ? const Color(0xFF374151)
                        : const Color(0xFF9CA3AF),
              ),
            ),
          ),
    );
  }
}

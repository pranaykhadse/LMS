import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';

// ignore: unused_element
const _purple = FigmaTokens.primaryPurple;
// CSS ref: .rw-summary-stars / .rw-stars — color #f59e0b (amber), not this
// app's usual purple accent.
const _starAmber = Color(0xFFF59E0B);

/// Opens the site's course-reviews modal for [courseId].
///
/// `GET /backend/web/course/load-reviews?id=<id>` (the same endpoint the
/// web app's own `openreviewsModal()` calls) returns a **static** HTML/CSS
/// fragment — no forms, no client-side interactivity, just server-rendered
/// display markup (`.rw-summary`, `.rw-card` list, an `.rw-empty` state).
/// Confirmed against a live capture of the actual response.
///
/// PENDING: there's no Bearer-token-authed REST endpoint for this data yet
/// (only that cookie-session-authenticated legacy web route), and fetching
/// it through an embedded WebView + auto-login link proved unreliable in
/// practice — the login-link resolves to a real, well-formed URL, but
/// visiting it still lands on the site's raw login form instead of
/// completing the auto-login handshake (confirmed even outside the
/// WebView, and even via the same mechanism Attend Class already uses
/// successfully elsewhere — so this is an upstream/server-side redirect
/// issue, not something fixable from here). Backend team is being asked
/// for a proper JSON endpoint. Until then this shows the modal's real
/// chrome/shell (matching the web app exactly) with no review content —
/// see [_ReviewsDialogState.build] for where to wire a real fetch back in
/// once that endpoint exists; [_ReviewSummary]/[_ReviewItem]/
/// [_SummaryRow]/[_ReviewCard] below are already built to render whatever
/// it returns.
void showReviewsModal(
  BuildContext context,
  WidgetRef ref, {
  required int courseId,
}) {
  showDialog<void>(
    context: context,
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

class _ReviewSummary {
  const _ReviewSummary({
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

class _ReviewsDialog extends ConsumerStatefulWidget {
  const _ReviewsDialog({required this.courseId});
  final int courseId;

  @override
  ConsumerState<_ReviewsDialog> createState() => _ReviewsDialogState();
}

class _ReviewsDialogState extends ConsumerState<_ReviewsDialog> {
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
                    // No fetch happens right now — see the doc comment on
                    // showReviewsModal for why. Once a real API exists,
                    // this becomes a normal loading/error/data switch
                    // (identical shape to every other screen in this app)
                    // instead of always going straight to the empty state.
                    child: _buildEmptyState(),
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
                child: _CloseButton(
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // CSS ref: .rw-empty — column, centered, gap 8px, padding 48px 0, color
  // #9CA3AF, 14px; icon 36px color #D1D5DB.
  Widget _buildEmptyState() {
    return const ColoredBox(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border_rounded, size: 36, color: Color(0xFFD1D5DB)),
            SizedBox(height: 8),
            Text(
              'No reviews yet',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary row ──────────────────────────────────────────────────────────
//
// Unused for now (see the doc comment on showReviewsModal) — kept ready
// for when a real reviews API exists: pass its data through
// _ReviewSummary/_ReviewItem and render `_SummaryRow(summary: ...)` +
// `_ReviewCard(item: ..., isLast: ...)` per item in place of
// _buildEmptyState() above.

// ignore: unused_element
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});
  final _ReviewSummary summary;

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

// ignore: unused_element
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

// ignore: unused_element
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
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF3F4F6)),
              ),
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
      builder: (context, hovering) => InkWell(
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
            color: hovering
                ? const Color(0xFF374151)
                : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}

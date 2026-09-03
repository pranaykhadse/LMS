import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/dashboard/model/badge.dart';
import 'package:lms/app/features/dashboard/viewmodel/badges_view_model.dart';

// ─── Staging exact tokens (backend/views/user-badges/index.php <style> on
// staging) — indigo family overridden to brand #693D94 per request (was
// #5C52D4 / FigmaTokens.primaryPurple). ────────────────────────────────────
const _indigo = Color(0xFF693D94); // brand (was #5C52D4)
const _indigoPink = Color(0xFFA20067); // avatar gradient end / lock hover
const _bodyBg = Color(0xFFF4F6FB); // staging #badges-wrap bg
const _textDark = Color(0xFF1E293B); // h1/h2
const _textBody = Color(0xFF475569); // modal sentence
const _muted = Color(0xFF6B7280); // de-emphasized / error
const _cardBorder = Color(0xFFF1F5F9); // earned badge border
const _lockedBorder = Color(0xFFE2E8F0); // locked badge border
const _lockedBg = Color(0xFFF8FAFC); // locked badge bg / modal header bg
const _divider = Color(0xFFF1F5F9); // h2 underline / modal border
const _cardShadow = [
  BoxShadow(color: Color(0x05000000), blurRadius: 3, offset: Offset(0, 1)),
];
const _badgeShadow = [
  BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 2)),
];

// Badges per row (CSS ref .badge-items child columns on staging):
// col-lg-2 → 6 at ≥992, col-md-3 → 4 at 768-991, col-6 → 2 below that
// (badges NEVER collapse to a single column).
int _badgeColumnsFor(double width) {
  if (width >= 992) return 6;
  if (width >= 768) return 4;
  return 2;
}

class BadgesPage extends ConsumerWidget {
  const BadgesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(BadgesViewModel.provider);
    final notifier = ref.read(BadgesViewModel.provider.notifier);
    final auth = ref.watch(AuthStateNotifier.provider);

    return AppScaffold(
      backgroundColor: _bodyBg,
      title: 'Badges',
      selectedSubLabel: 'Badges',
      onRefresh: notifier.fetch,
      body: _Body(
        state: state,
        onRetry: notifier.fetch,
        userProfile: auth?.userProfile,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.onRetry, this.userProfile});
  final BadgesState state;
  final VoidCallback onRetry;
  final UserProfile? userProfile;

  @override
  Widget build(BuildContext context) {
    switch (state.providerState) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(child: CircularProgressIndicator(color: _indigo));
      case DataProviderState.error:
        return _ErrorView(
          message: friendlyErrorMessage(state.error, 'Unable to load badges.'),
          onRetry: onRetry,
        );
      case DataProviderState.data:
        final result = state.result!;
        final w = MediaQuery.sizeOf(context).width;
        // CSS ref: #badges-wrap padding 40px 0, 20px ≤768. The web's
        // .content-wrap/.container add no horizontal padding (and the row's
        // -15px margins cancel the col padding), so the profile card and
        // badge blocks span the full window width at every breakpoint.
        final isPhone = w <= 768;
        final topPad = isPhone ? 20.0 : 40.0;
        // Cards sit inside a 16px cushion from the screen edges at every
        // breakpoint.
        const hPad = 16.0;
        // CSS ref: .badges-profile is col-12 below 768 (stacked full width);
        // side-by-side at col-md-3/9 (≥768) and col-lg-2/10 (≥992).
        final sideBySide = w >= 768;
        final content =
            sideBySide
                ? _rowLayout(w, (w - 2 * hPad) + 30, result)
                : _stackedLayout(result, isPhone);
        // Per explicit request: the footer should span the full window
        // width on every screen, like the header above it — it was the
        // last child of this ListView, inheriting the ListView's own
        // horizontal `padding` instead of running edge to edge.
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: _indigo,
                onRefresh: () async => onRetry(),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, 32),
                  children: [content, const SizedBox(height: 24)],
                ),
              ),
            ),
            const AppFooter(),
          ],
        );
    }
  }

  Widget _rowLayout(double w, double rowW, BadgesResult result) {
    // Profile column shares: 2/12 (≥992) or 3/12 (768-991) of the web row
    // (container+30 due to the .row -15px margins), minus both 15px col
    // paddings; the remaining width (minus the 30px gutter) is the badges.
    final profileW = (rowW * (w >= 992 ? 2 / 12 : 3 / 12) - 30).clamp(
      120.0,
      300.0,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: profileW,
          child: _ProfileCard(userProfile: userProfile),
        ),
        const SizedBox(width: 30),
        Expanded(child: _BadgesContent(result: result, isPhone: false)),
      ],
    );
  }

  Widget _stackedLayout(BadgesResult result, bool isPhone) {
    return Column(
      children: [
        _ProfileCard(userProfile: userProfile),
        // CSS ref: .badges-profile margin-bottom 20px ≤768
        SizedBox(height: isPhone ? 20 : 24),
        _BadgesContent(result: result, isPhone: isPhone),
      ],
    );
  }
}

// ─── Profile card (web .badges-profile, col-lg-2/col-md-3) ───────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({this.userProfile});
  final UserProfile? userProfile;

  @override
  Widget build(BuildContext context) {
    final name = [
      userProfile?.firstname ?? '',
      userProfile?.lastname ?? '',
    ].where((s) => s.isNotEmpty).join(' ');
    final avatarUrl = userProfile?.avatarUrl ?? '';
    final firstInitial =
        (userProfile?.firstname?.isNotEmpty ?? false)
            ? userProfile!.firstname![0].toUpperCase()
            : '?';
    final isPhone = MediaQuery.sizeOf(context).width <= 768;

    // CSS ref: .badges-profile — padding 24 (20 ≤768), radius 16, border 1px
    // #F3F4F6, shadow 0 1px 3px rgba(0,0,0,.02), centered column.
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isPhone ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: _cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // .badges-profile img: 120x120, radius 50%, border 3px solid
          // rgba(brand,.1). Fallback span: gradient 135deg brand→#A20067,
          // white 32px/700 initial.
          avatarUrl.isNotEmpty
              ? Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _indigo.withValues(alpha: 0.1),
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: NetworkImage(avatarUrl),
                ),
              )
              : Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_indigo, _indigoPink],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  firstInitial,
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          // CSS ref: img/span margin 0 auto 15px auto
          const SizedBox(height: 15),
          // .badges-profile h1: 16px/700/#1E293B, line-height 1.4
          Text(
            _titleCase(name).isEmpty ? 'User' : _titleCase(name),
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              color: _textDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

String _titleCase(String s) {
  if (s.isEmpty) return s;
  return s
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

// ─── Badges content (web .badges-block columns) ──────────────────────────────

class _BadgesContent extends StatelessWidget {
  const _BadgesContent({required this.result, required this.isPhone});
  final BadgesResult result;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    // CSS ref: .badges-block margin-bottom 24 (20 ≤768).
    final gap = isPhone ? 20.0 : 24.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BadgesBlock(
          title: 'Your Badges',
          badges: result.earned,
          earned: true,
          isPhone: isPhone,
        ),
        SizedBox(height: gap),
        _BadgesBlock(
          title: 'Available Badges',
          badges: result.notEarned,
          earned: false,
          isPhone: isPhone,
        ),
      ],
    );
  }
}

class _BadgesBlock extends StatelessWidget {
  const _BadgesBlock({
    required this.title,
    required this.badges,
    required this.earned,
    required this.isPhone,
  });
  final String title;
  final List<UserBadge> badges;
  final bool earned;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    // CSS ref: .badges-block — padding 30 (20 16 ≤768), radius 16, border
    // 1px #F3F4F6, shadow 0 1px 3px rgba(0,0,0,.02).
    return Container(
      width: double.infinity,
      padding:
          isPhone
              ? const EdgeInsets.fromLTRB(16, 20, 16, 20)
              : const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title),
          // CSS ref: h2 margin-bottom 20px
          const SizedBox(height: 20),
          if (badges.isNotEmpty)
            _BadgeGrid(badges: badges, earned: earned, isPhone: isPhone),
        ],
      ),
    );
  }
}

// ─── Section header (web .badges-block h2) ───────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    // CSS ref: h2 — 18px/700/#1E293B, border-bottom 2px #F1F5F9,
    // padding-bottom 12px.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _divider, width: 2)),
      ),
      child: Text(
        title,
        style: GoogleFonts.roboto(
          color: _textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Badge grid (web .badge-items) with 12/page pagination (web pageSize 12) ─

const _badgePageSize = 12;

class _BadgeGrid extends StatefulWidget {
  const _BadgeGrid({
    required this.badges,
    required this.earned,
    required this.isPhone,
  });
  final List<UserBadge> badges;
  final bool earned;
  final bool isPhone;

  @override
  State<_BadgeGrid> createState() => _BadgeGridState();
}

class _BadgeGridState extends State<_BadgeGrid> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final pages = (widget.badges.length / _badgePageSize).ceil();
    final page = _page.clamp(0, pages - 1);
    final visible =
        widget.badges.skip(page * _badgePageSize).take(_badgePageSize).toList();
    // CSS ref: desktop/.badge-items — Bootstrap row gutter 30px horizontal,
    // .my-1 → 8px vertical; ≤768 media query — margin -6 + padding 6 → 12px.
    final crossGap = widget.isPhone ? 12.0 : 30.0;
    final mainGap = widget.isPhone ? 12.0 : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _badgeColumnsFor(w),
            crossAxisSpacing: crossGap,
            mainAxisSpacing: mainGap,
            childAspectRatio: 1.0,
          ),
          itemCount: visible.length,
          itemBuilder:
              (ctx, i) => _BadgeCard(badge: visible[i], earned: widget.earned),
        ),
        if (pages > 1) ...[
          // CSS ref: layout '<div class="mt-4 d-flex justify-content-center">{pager}</div>'
          const SizedBox(height: 24),
          Center(
            child: _Pager(
              page: page,
              pages: pages,
              onPage: (p) => setState(() => _page = p),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Badge card (web .badge-container + .locked + .lock-icon) ────────────────

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge, required this.earned});
  final UserBadge badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final locked = !earned;
    // CSS ref ≤768 media query caps the badge img at 60px.
    final isSmall = MediaQuery.sizeOf(context).width <= 768;
    return MouseRegion(
      cursor: locked ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: HoverBuilder(
        builder: (context, hovering) {
          // CSS ref: base .badge-container — radius 16, padding 12, bg white
          // (.locked #F8FAFC), border #F1F5F9 (.locked #E2E8F0), aspect 1/1,
          // shadow 0 2px 8px rgba(0,0,0,.02). Hover: translateY(-4px),
          // shadow 0 12px 24px rgba(brand,.08), border rgba(brand,.15).
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, hovering ? -4 : 0, 0),
            decoration: BoxDecoration(
              color: locked ? _lockedBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    hovering
                        ? _indigo.withValues(alpha: 0.15)
                        : (locked ? _lockedBorder : _cardBorder),
              ),
              boxShadow:
                  hovering
                      ? [
                        BoxShadow(
                          color: _indigo.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ]
                      : _badgeShadow,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap:
                  earned
                      ? () => showDialog(
                        context: context,
                        builder: (_) => _BadgeDetailDialog(badge: badge),
                      )
                      : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // CSS ref: .badge-container img padding 4px, object-fit
                  // contain; .locked img grayscale(100%) opacity(40%) →
                  // hover grayscale(60%) opacity(60%). At ≤768 the media
                  // query caps the img at 60px max-width.
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child:
                        isSmall
                            ? Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 60,
                                  maxHeight: 60,
                                ),
                                child: _BadgeImage(
                                  imageUrl: badge.image,
                                  earned: earned,
                                  lockedHover: locked && hovering,
                                ),
                              ),
                            )
                            : _BadgeImage(
                              imageUrl: badge.image,
                              earned: earned,
                              lockedHover: locked && hovering,
                            ),
                  ),
                  if (locked)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      // CSS ref: .lock-icon — 32x32, bg rgba(brand,.9) →
                      // hover rgba(#A20067,.95), border 2 white, shadow
                      // 0 4px 14px rgba(brand,.35) → hover 0 6px 18px
                      // rgba(#A20067,.45), scale 1.1.
                      child: AnimatedScale(
                        scale: hovering ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                hovering
                                    ? _indigoPink.withValues(alpha: 0.95)
                                    : _indigo.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow:
                                hovering
                                    ? [
                                      BoxShadow(
                                        color: _indigoPink.withValues(
                                          alpha: 0.45,
                                        ),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                    : [
                                      BoxShadow(
                                        color: _indigo.withValues(alpha: 0.35),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Badge image (web .badge-container img / locked filter) ─────────────────

class _BadgeImage extends StatelessWidget {
  const _BadgeImage({
    this.imageUrl,
    required this.earned,
    this.lockedHover = false,
  });
  final String? imageUrl;
  final bool earned;
  // Shadows the web .locked hover: grayscale(60%) opacity(60%) vs base
  // grayscale(100%) opacity(40%).
  final bool lockedHover;

  static List<double> _grayMatrix(double p, double o) {
    // CSS grayscale(p) then opacity(o). grayscale(1) = luminance matrix.
    const g = 0.2126, r = 0.7152, b = 0.0722;
    final i = 1 - p;
    return [
      (p * g + i) * o,
      p * r * o,
      p * b * o,
      0,
      0,
      p * g * o,
      (p * r + i) * o,
      p * b * o,
      0,
      0,
      p * g * o,
      p * r * o,
      (p * b + i) * o,
      0,
      0,
      0,
      0,
      0,
      o,
      0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    // For earned badges the image sits directly on the card bg (white); for
    // locked ones on #F8FAFC. The image itself is transparent PNG art, so no
    // extra backdrop is needed — a transparent Image paints the card bg.
    final p = earned ? 0.0 : (lockedHover ? 0.6 : 1.0);
    final o = earned ? 1.0 : (lockedHover ? 0.6 : 0.4);
    final fallback = Icon(
      Icons.military_tech_rounded,
      size: 60,
      color: earned ? const Color(0xFFFFC107) : _muted,
    );
    final child =
        imageUrl == null || imageUrl!.isEmpty
            ? fallback
            : Image.network(
              imageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => fallback,
            );
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_grayMatrix(p, o)),
      child: child,
    );
  }
}

// ─── Badge detail modal (web #earn-badges-modal) ─────────────────────────────

class _BadgeDetailDialog extends StatelessWidget {
  const _BadgeDetailDialog({required this.badge});
  final UserBadge badge;

  @override
  Widget build(BuildContext context) {
    // CSS ref: modal-content radius 16, shadow 0 10px 40px rgba(0,0,0,.1);
    // header bg #F8FAFC border-bottom #F1F5F9 padding 16/20 (close only);
    // body padding 30/24; image max-width 110; p 15px/#475569/lh1.6;
    // strong brand/18px.
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: _lockedBg,
              border: Border(bottom: BorderSide(color: _divider)),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: _muted, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: _BadgeImage(imageUrl: badge.image, earned: true),
                ),
                const SizedBox(height: 15),
                Text.rich(
                  TextSpan(
                    style: GoogleFonts.roboto(
                      color: _textBody,
                      fontSize: 15,
                      height: 1.6,
                    ),
                    children: [
                      TextSpan(
                        text:
                            'You earned this badge for successfully completing the course ‘${badge.title}’',
                      ),
                      const TextSpan(text: '\n\n'),
                      const TextSpan(
                        text: 'Congratulations!',
                        style: TextStyle(
                          color: _indigo,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pagination pager (web Yiinode LinkPager under each >12 section) ─────────

class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.pages, required this.onPage});
  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final numbers = _pageNumbers(page, pages);
    return Wrap(
      spacing: 3,
      children:
          numbers.map((p) {
            if (p == -1) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(
                  '...',
                  style: GoogleFonts.roboto(color: _muted, fontSize: 14),
                ),
              );
            }
            final isCurrent = p == page;
            return InkWell(
              onTap: isCurrent ? null : () => onPage(p),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isCurrent ? _indigo : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrent ? _indigo : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Text(
                  '$p',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isCurrent ? Colors.white : const Color(0xFF374151),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

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

// ─── Error view ──────────────────────────────────────────────────────────────

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
              style: GoogleFonts.roboto(color: _muted),
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

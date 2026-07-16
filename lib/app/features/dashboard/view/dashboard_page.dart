import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/dashboard/view/my_courses_page.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/viewmodel/dashboard_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

const _purple = Color(0xFF5756C9);
const _purple2 = Color(0xFF775FE8);
const _ink = Color(0xFF172033);
const _muted = Color(0xFF7C879D);
const _bg = Color(0xFFF5F7FC);

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    final state = ref.watch(DashboardViewModel.provider);

    return Scaffold(
      backgroundColor: _bg,
      drawer: const _DashboardDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: _DashboardAppBar(auth: auth),
      ),
      body: _DashboardBody(auth: auth, state: state, ref: ref),
    );
  }
}

// ─── AppBar ──────────────────────────────────────────────────────────────────

class _DashboardAppBar extends ConsumerWidget {
  const _DashboardAppBar({required this.auth});
  final AuthState? auth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = auth?.userProfile;
    final canPop = Navigator.canPop(context);
    return AppBar(
      backgroundColor: _purple,
      foregroundColor: Colors.white,
      elevation: 2,
      centerTitle: true,
      leadingWidth: canPop ? 106 : 68,
      leading: Builder(
        builder:
            (ctx) => Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canPop) ...[
                      _IconBtn(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 6),
                    ],
                    _IconBtn(
                      icon: Icons.menu_rounded,
                      onTap: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ],
                ),
              ),
            ),
      ),
      title: const Text(
        'Dashboard',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      actions: [
        _IconBtn(icon: Icons.notifications_rounded, onTap: () => _showNotifications(context), boxed: false),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          offset: const Offset(0, 54),
          constraints: const BoxConstraints(minWidth: 290, maxWidth: 390),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          onSelected: (value) {
            if (value == 'logout') {
              ref.read(AuthStateNotifier.provider.notifier).logout();
              Modular.to.navigate('/');
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              padding: EdgeInsets.zero,
              child: _ProfileHeader(profile: profile),
            ),
            const PopupMenuItem<String>(
              value: 'settings',
              child: _ProfileMenuRow(
                icon: Icons.settings,
                label: 'Account Settings',
              ),
            ),
            PopupMenuItem<String>(
              enabled: false,
              child: _ProfileMenuRow(
                icon: Icons.workspace_premium_outlined,
                label: 'My Points: ${profile?.points ?? 0}',
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'logout',
              child: _ProfileMenuRow(
                icon: Icons.logout,
                label: 'Logout Account',
              ),
            ),
          ],
          child: _AvatarCircle(profile: profile),
        ),
        const SizedBox(width: 14),
      ],
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.auth,
    required this.state,
    required this.ref,
  });
  final AuthState? auth;
  final DataState<DashboardResponse> state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    switch (state.state) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(child: CircularProgressIndicator(color: _purple));
      case DataProviderState.error:
        return _ErrorView(
          message: state.error ?? 'Unable to load dashboard.',
          onRetry: () => ref.read(DashboardViewModel.provider.notifier).fetch(),
        );
      case DataProviderState.data:
        final data = state.data;
        if (data == null) {
          return const _ErrorView(message: 'No dashboard data found.');
        }
        return RefreshIndicator(
          color: _purple,
          onRefresh:
              () => ref.read(DashboardViewModel.provider.notifier).fetch(),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _BannerSection(auth: auth),
              if (data.ongoingCourses.isNotEmpty) ...[
                const SizedBox(height: 28),
                _SectionHeader(
                  title: 'My Courses',
                  actionLabel: 'View All My Courses',
                  onAction:
                      () => Modular.to.pushNamed(
                        CoursesModule.construct(CoursesModule.myCourses),
                      ),
                ),
                const SizedBox(height: 16),
                _CourseCarousel(courses: data.ongoingCourses),
              ],
              if (data.resources.isNotEmpty) ...[
                const SizedBox(height: 28),
                const _SectionHeader(title: 'Resources'),
                const SizedBox(height: 16),
                _ResourceCarousel(resources: data.resources),
              ],
              const SizedBox(height: 48),
            ],
          ),
        );
    }
  }
}

// ─── Banner ───────────────────────────────────────────────────────────────────

class _BannerSection extends StatelessWidget {
  const _BannerSection({required this.auth});
  final AuthState? auth;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  String _userName() {
    final p = auth?.userProfile;
    final first = p?.firstname?.trim() ?? '';
    final last = p?.lastname?.trim() ?? '';
    final name = [first, last].where((s) => s.isNotEmpty).join(' ');
    return name.isNotEmpty ? name : auth?.user?.username ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1255), _purple2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good ${_greeting()}, ${_userName()}!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '"A leader is best when people barely know he exists; '
            'when his work is done, his aim fulfilled, '
            'they will all say: We did it ourselves."',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '— Lao-Tzu',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: _purple,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  color: _purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: _purple,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Course carousel ──────────────────────────────────────────────────────────

class _CourseCarousel extends StatelessWidget {
  const _CourseCarousel({required this.courses});
  final List<DashboardCourse> courses;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.62,
        ),
        itemCount: courses.length,
        itemBuilder: (context, index) => _CourseCard(course: courses[index]),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});
  final DashboardCourse course;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          SizedBox(
            height: 110,
            width: double.infinity,
            child:
                course.logo != null
                    ? Image.network(
                      course.logo!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _ImgFallback(),
                    )
                    : const _ImgFallback(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (course.displayRating) ...[
                    _StarRow(
                      rating: course.averageRating,
                      count: course.ratingCount,
                    ),
                    const SizedBox(height: 6),
                  ] else
                    const SizedBox(height: 2),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          () => Modular.to.pushNamed(
                            CoursesModule.construct(
                              '${CoursesModule.detail}/${course.id}',
                            ),
                          ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      child: const Text('View Course'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Resource carousel ────────────────────────────────────────────────────────

class _ResourceCarousel extends StatelessWidget {
  const _ResourceCarousel({required this.resources});
  final List<DashboardResource> resources;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.68,
        ),
        itemCount: resources.length,
        itemBuilder:
            (context, index) => _ResourceCard(resource: resources[index]),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource});
  final DashboardResource resource;

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final hasAction = resource.actionType != 'none';
    final label =
        resource.actionType == 'link'
            ? 'Open Link'
            : resource.actionType == 'resource'
            ? 'View Resource'
            : 'No Content';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 110,
                width: double.infinity,
                child: resource.logo != null
                    ? Image.network(
                        resource.logo!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _ImgFallback(),
                      )
                    : const _ImgFallback(),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'RESOURCE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  if (resource.subtitle?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      resource.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: hasAction
                        ? OutlinedButton(
                            onPressed: () {
                              if (resource.actionType == 'link' &&
                                  resource.actionUrl != null) {
                                _openLink(resource.actionUrl!);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _purple,
                              side: const BorderSide(color: _purple),
                              minimumSize: const Size.fromHeight(32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            child: Text(label),
                          )
                        : OutlinedButton(
                            onPressed: null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _muted,
                              side: const BorderSide(color: Color(0xFFDDE2EA)),
                              minimumSize: const Size.fromHeight(32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            child: Text(label),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Star rating ──────────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < rating.floor()) {
            return const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 15);
          }
          if (i < rating) {
            return const Icon(
              Icons.star_half_rounded,
              color: Color(0xFFFFC107),
              size: 15,
            );
          }
          return const Icon(
            Icons.star_border_rounded,
            color: Color(0xFFFFC107),
            size: 15,
          );
        }),
        const SizedBox(width: 4),
        Text(
          '${rating.toStringAsFixed(1)} ($count)',
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    );
  }
}

// ─── Image fallback ───────────────────────────────────────────────────────────

class _ImgFallback extends StatelessWidget {
  const _ImgFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0ECFF),
      alignment: Alignment.center,
      child: const Icon(Icons.school_outlined, color: _purple, size: 54),
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
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(backgroundColor: _purple),
                child: const Text(
                  'Try Again',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Drawer ───────────────────────────────────────────────────────────────────

class _DashboardDrawer extends ConsumerWidget {
  const _DashboardDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    final title =
        auth?.group?.isNotEmpty == true
            ? auth!.group!.first.name
            : 'Main Menu';
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: (width * .8).clamp(300, 315).toDouble(),
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 13, 14, 54),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title?.toUpperCase() ?? 'MAIN MENU',
                      style: const TextStyle(
                        color: _purple,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 26),
              child: Text(
                'MAIN NAVIGATION',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _muted,
                ),
              ),
            ),
            const SizedBox(height: 27),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _DrawerItem(
                      icon: Icons.dashboard_outlined,
                      label: 'Dashboard',
                      selected: true,
                      onTap: () => Navigator.pop(context),
                    ),
                    _DrawerItem(
                      icon: Icons.menu_book_outlined,
                      label: 'Course Catalog',
                      onTap: () {
                        Navigator.pop(context);
                        Modular.to.pushNamed(
                          CoursesModule.construct(CoursesModule.root),
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.library_books_outlined,
                      label: 'My Courses',
                      children: [
                        _SubItem(
                          label: 'My Enrolled Courses',
                          icon: Icons.school_outlined,
                          onTap: () {
                            Navigator.pop(context);
                            Modular.to.pushNamed(
                              CoursesModule.construct(CoursesModule.enrolledCourses),
                            );
                          },
                        ),
                        _SubItem(
                          label: 'My Completed Courses',
                          icon: Icons.task_alt,
                          onTap: () {
                            Navigator.pop(context);
                            Modular.to.pushNamed(
                              CoursesModule.construct(CoursesModule.completedCourses),
                            );
                          },
                        ),
                        _SubItem(
                          label: 'My Development Plan',
                          icon: Icons.timeline_outlined,
                          onTap: () {
                            Navigator.pop(context);
                            Modular.to.pushNamed(
                              CoursesModule.construct(CoursesModule.developmentPlan),
                            );
                          },
                        ),
                        _SubItem(
                          label: 'My Required Courses',
                          icon: Icons.assignment_outlined,
                          onTap: () {
                            Navigator.pop(context);
                            Modular.to.pushNamed(
                              CoursesModule.construct(CoursesModule.requiredCourses),
                            );
                          },
                        ),
                      ],
                    ),
                    _DrawerItem(
                      icon: Icons.account_tree_outlined,
                      label: 'Learning Paths',
                      onTap: () {
                        Navigator.pop(context);
                        Modular.to.pushNamed(
                          CoursesModule.construct(CoursesModule.learningPaths),
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.workspace_premium_outlined,
                      label: 'Points & Badges',
                      children: [
                        _SubItem(
                          label: 'Badges',
                          icon: Icons.military_tech_outlined,
                          onTap: () {
                            Navigator.pop(context);
                            Modular.to.pushNamed(
                              CoursesModule.construct(CoursesModule.badges),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubItem {
  const _SubItem({required this.label, this.icon, this.onTap});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.trailing = false,
    this.onTap,
    this.children = const [],
  });
  final IconData icon;
  final String label;
  final bool selected;
  final bool trailing;
  final VoidCallback? onTap;
  final List<_SubItem> children;

  Widget _iconBox(bool isSelected) => Container(
    width: 37,
    height: 37,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: isSelected ? const Color(0xFFE8E7F8) : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Icon(icon, size: 20, color: isSelected ? _purple : _muted),
  );

  @override
  Widget build(BuildContext context) {
    if (children.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 2),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            childrenPadding: const EdgeInsets.only(left: 16, bottom: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: _iconBox(false),
            title: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF354056),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            iconColor: _muted,
            collapsedIconColor: _muted,
            children: children.map((sub) => ListTile(
              dense: true,
              contentPadding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
              leading: sub.icon != null
                  ? Icon(sub.icon, size: 18, color: _muted)
                  : const SizedBox(width: 18),
              title: Text(
                sub.label,
                style: const TextStyle(
                  color: Color(0xFF354056),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: sub.onTap,
            )).toList(),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF0EFFF) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _iconBox(selected),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? _purple : const Color(0xFF354056),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing)
                const Icon(Icons.arrow_forward_ios, size: 14, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Profile popup widgets ────────────────────────────────────────────────────

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.profile});
  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    final base = profile?.avatarBaseUrl?.toString() ?? '';
    final path = profile?.avatarPath?.toString() ?? '';
    final url = path.startsWith('http') ? path : (base.isNotEmpty && path.isNotEmpty ? '$base$path' : '');
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.white,
      child: CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFF10121B),
        backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
        child: url.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});
  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    final name = '${profile?.firstname ?? ''} ${profile?.lastname ?? ''}'.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7A42C4), Color(0xFFB0006D)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          _AvatarCircle(profile: profile),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'User' : name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'USER',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 21, color: _muted),
      const SizedBox(width: 13),
      Text(label, style: const TextStyle(color: Color(0xFF4C586C), fontSize: 15)),
    ],
  );
}

// ─── Icon button ──────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap, this.boxed = true});
  final IconData icon;
  final VoidCallback onTap;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          boxed ? Colors.white.withValues(alpha: .12) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: boxed ? 38 : 34,
          height: boxed ? 38 : 34,
          child: Icon(icon, color: Colors.white, size: boxed ? 27 : 24),
        ),
      ),
    );
  }
}

// ─── Notifications dialog ─────────────────────────────────────────────────────

void _showNotifications(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black26,
    builder: (context) => Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(16, 76, 16, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'Mark all as read',
                    style: TextStyle(
                      color: _purple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 42),
            const CircleAvatar(
              backgroundColor: Color(0xFF24C56B),
              child: Icon(Icons.check, color: Colors.white, size: 27),
            ),
            const SizedBox(height: 18),
            const Text(
              "You're all caught up",
              style: TextStyle(
                color: Color(0xFF9AA8C0),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 40),
            InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFBFD),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(18),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'View All Notifications',
                    style: TextStyle(
                      color: _purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

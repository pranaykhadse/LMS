import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/view/lms_app_bar.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';
import 'package:lms/app/features/dashboard/view/app_drawer.dart';
import 'package:lms/app/features/dashboard/view/my_courses_page.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/viewmodel/dashboard_view_model.dart';
import 'package:lms/app_module.dart';
import 'package:url_launcher/url_launcher.dart';

const _purple = Color(0xFF5756C9);
const _purple2 = Color(0xFF775FE8);
const _ink = Color(0xFF172033);
const _muted = Color(0xFF7C879D);
const _bg = Color(0xFFF5F7FC);

bool _watchIsOnline(WidgetRef ref) {
  final isManualOffline = ref.watch(OfflineModeNotifier.provider);
  final connectionVM = ref.watch(InternetConnectionProvider.provider);
  ref.watch(SyncViewModel.provider);
  return !isManualOffline && connectionVM.isConnected;
}

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _redirectingUnauthorized = false;

  static bool _isUnauthorizedError(String? error) {
    final v = error?.toLowerCase() ?? '';
    return v.startsWith('unauthorized') ||
        v.contains('invalid credentials') ||
        v.contains('status code of 401') ||
        v.contains(' 401');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(AuthStateNotifier.provider);
    final state = ref.watch(DashboardViewModel.provider);

    if (!_redirectingUnauthorized &&
        state.state == DataProviderState.error &&
        _isUnauthorizedError(state.error)) {
      _redirectingUnauthorized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your session has expired. Please log in again.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 3),
          ),
        );
        await ref.read(AuthStateNotifier.provider.notifier).logout();
        if (!mounted) return;
        Modular.to.navigate(AppModule.auth);
      });
    }

    return Scaffold(
      backgroundColor: _bg,
      drawer: const AppDrawer(selectedLabel: 'Dashboard'),
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: LmsAppBar(title: 'Dashboard', centerTitle: true),
      ),
      body: _redirectingUnauthorized
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : _DashboardBody(auth: auth, state: state, ref: ref),
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

class _ResourceCard extends ConsumerWidget {
  const _ResourceCard({required this.resource});
  final DashboardResource resource;

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = _watchIsOnline(ref);
    final needsInternet = resource.actionType == 'link';
    final hasAction = resource.actionType != 'none' && (!needsInternet || isOnline);
    final label =
        resource.actionType == 'link'
            ? (isOnline ? 'Open Link' : 'Internet required')
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


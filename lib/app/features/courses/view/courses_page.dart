import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/model/page_info.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/views/elements/connection_aware_widget.dart';
import 'package:lms/app/core/views/elements/offline_banner.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/viewmodel/courses_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/offline_view_model.dart';
import 'package:lms/gen/assets.gen.dart';

class CoursesPage extends ConsumerStatefulWidget {
  const CoursesPage({super.key});

  @override
  ConsumerState<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<CoursesPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _query = '';
  late final TabController _tabController;

  static const _tabs = ['All Courses', 'My Courses'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<Course> _filtered(List<Course> courses) {
    var list = courses;
    // Req #9: My Courses tab filters to enrolled courses only.
    if (_tabController.index == 1) {
      list = list.where((c) => c.roasters?.isNotEmpty == true).toList();
    }
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list.where((c) => (c.name ?? '').toLowerCase().contains(q)).toList();
  }

  /// Floats offline courses (sorted newest-first by download timestamp) above
  /// the rest of the list.
  List<Course> _sortedByOfflineFirst(
    List<Course> courses,
    OfflineViewModel offlineVM,
  ) {
    final offline = <Course>[];
    final rest = <Course>[];
    for (final c in courses) {
      if (offlineVM.isAvailable(c)) {
        offline.add(c);
      } else {
        rest.add(c);
      }
    }
    offline.sort((a, b) =>
        (offlineVM.offlineTimestamps[b.id] ?? 0)
            .compareTo(offlineVM.offlineTimestamps[a.id] ?? 0));
    return [...offline, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FlatAppBar(title: "Courses", enableBack: false),
      body: Padding(
        padding: EdgeInsets.all(context.smallSpace),
        child: PrimaryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Offline / re-sync banner ───────────────────────────────
              const OfflineBanner(),

              Padding(
                padding: EdgeInsets.only(
                  left: context.smallSpace,
                  right: context.smallSpace,
                  top: context.smallSpace,
                  bottom: context.minorSpace,
                ),
                child: Text(
                  "Leadership Edge Live Courses",
                  style: context.textTheme.titleLarge?.copyWith(
                    color: context.appColorScheme.primary,
                  ),
                ),
              ),

              // ── Tabs: All Courses / My Courses (Req #9) ──────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.smallSpace),
                child: TabBar(
                  controller: _tabController,
                  tabs: _tabs.map((t) => Tab(text: t)).toList(),
                  labelColor: context.appColorScheme.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: context.appColorScheme.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: context.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),

              // ── Search bar ────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.smallSpace,
                  vertical: context.minorSpace,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search courses…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: context.appColorScheme.primary,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),

              Expanded(
                child: ConnectionAwareWidget(
                  offlineChild: Consumer(
                    builder: (context, ref, child) {
                      final offlineVM = ref.watch(OfflineViewModel.provider);
                      final isManualOffline =
                          ref.watch(OfflineModeNotifier.provider);
                      final raw = offlineVM.courses.data ?? [];
                      final data = _filtered(raw);
                      if (raw.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cloud_off_rounded,
                                  size: 56,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  isManualOffline
                                      ? "No courses downloaded yet.\nDisable Offline Mode to browse all courses."
                                      : "No downloaded courses found.\nConnect to the internet to load your courses.",
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      if (data.isEmpty) {
                        return const Center(
                          child: Text("No courses match your search."),
                        );
                      }
                      return CoursesGrid(data: data);
                    },
                  ),
                  onlineChild: Consumer(
                    builder: (context, ref, child) {
                      final state = ref.watch(CoursesViewModel.provider);
                      final offlineVM = ref.watch(OfflineViewModel.provider);

                      return Column(
                        children: [
                          Expanded(
                            child: DataStateBuilder(
                              dataState: state.data,
                              builder: (context, raw) {
                                if (raw == null || raw.isEmpty) {
                                  return const Center(
                                    child: Text("No courses found"),
                                  );
                                }
                                final data = _sortedByOfflineFirst(
                                  _filtered(raw),
                                  offlineVM,
                                );
                                if (data.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      "No courses match your search.",
                                    ),
                                  );
                                }
                                return CoursesGrid(data: data);
                              },
                            ),
                          ),
                          PaginationWidget(
                            pageInfo: state.pageInfo ?? PageInfo(),
                            onPageChange: (value) {
                              ref
                                  .read(CoursesViewModel.provider.notifier)
                                  .fetch(value);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CoursesGrid extends StatelessWidget {
  const CoursesGrid({super.key, required this.data});
  final List<Course> data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use a 2-column grid on macOS when wide enough — never on iOS.
        final wide = defaultTargetPlatform == TargetPlatform.macOS &&
            constraints.maxWidth >= 700;
        final padding = EdgeInsets.all(context.smallSpace);
        const cardHeight = 180.0;

        if (wide) {
          return GridView.builder(
            padding: padding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: context.smallSpace,
              mainAxisSpacing: context.smallSpace,
              mainAxisExtent: cardHeight,
            ),
            itemCount: data.length,
            itemBuilder: (context, index) =>
                CourseCard(course: data[index]),
          );
        }

        // Narrow (mobile / narrow macOS window) — single column list.
        return ListView.builder(
          padding: padding,
          itemCount: data.length,
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.only(bottom: context.smallSpace),
            child: SizedBox(
              height: cardHeight,
              child: CourseCard(course: data[index]),
            ),
          ),
        );
      },
    );
  }
}

class CourseCard extends ConsumerWidget {
  const CourseCard({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineVM = ref.watch(OfflineViewModel.provider);

    final isDownloading = offlineVM.isDownloading(course);
    final isAvailableOffline = offlineVM.isAvailable(course);

    return SecondaryCard(
      onTap: () {
        // Pass the full Course object so the detail page can show the
        // participant guide and other course-level data.
        Modular.to.pushNamed(
          CoursesModule.construct("${CoursesModule.detail}/${course.id}"),
          arguments: course,
        );
      },
      padding: EdgeInsets.zero,
      child: Column(
        spacing: context.smallSpace,
        children: [
          // ── Course image / thumbnail ─────────────────────────────────────
          Expanded(
            flex: 2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Assets.images.loginBg.image(fit: BoxFit.cover),
                // ── "Available Offline" badge ──────────────────────────────
                if (isAvailableOffline)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.offline_pin_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "Available Offline",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Course info & action buttons ─────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: context.appColorScheme.secondary,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Course name
                      Text(
                        course.name ?? '',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.onPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Action buttons row
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          // View Course button
                          _ViewButton(),

                          // Offline button
                          _OfflineButton(
                            course: course,
                            offlineVM: offlineVM,
                            isDownloading: isDownloading,
                            isAvailableOffline: isAvailableOffline,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Completion progress ring ───────────────────────────────
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: course.percentage,
                        color: context.colorScheme.primary,
                        backgroundColor: Colors.white,
                        strokeWidth: 3,
                      ),
                      Center(
                        child: Text(
                          "${(course.percentage * 100).toInt()}%",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action button widgets
// ─────────────────────────────────────────────────────────────────────────────

/// "View Course" button — shown for all courses.
class _ViewButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.minorRadius),
        border: Border.all(color: context.colorScheme.onPrimary),
      ),
      padding: EdgeInsets.all(context.minorSpace),
      child: Text(
        "View Course",
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onPrimary,
        ),
      ),
    );
  }
}

/// "Browse Offline" / progress bar / "Remove from Offline" button.
class _OfflineButton extends StatelessWidget {
  const _OfflineButton({
    required this.course,
    required this.offlineVM,
    required this.isDownloading,
    required this.isAvailableOffline,
  });

  final Course course;
  final OfflineViewModel offlineVM;
  final bool isDownloading;
  final bool isAvailableOffline;

  @override
  Widget build(BuildContext context) {
    final progress = offlineVM.downloadProgress(course);

    return InkWell(
      onTap: isDownloading
          ? null
          : () async {
              try {
                if (isAvailableOffline) {
                  await offlineVM.removeOffline(course);
                } else {
                  // Req #1: validate enrollment before download
                  final isEnrolled = course.roasters?.isNotEmpty == true;
                  if (!isEnrolled) {
                    // ignore: use_build_context_synchronously
                    Toast.error(
                      context,
                      "You must be enrolled in this course to download it.",
                    );
                    return;
                  }
                  await offlineVM.download(course);
                }
              } catch (e) {
                // ignore: use_build_context_synchronously
                Toast.error(context, e.toString());
              }
            },
      borderRadius: BorderRadius.circular(context.minorRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.minorRadius),
          color: isAvailableOffline
              ? Colors.red.shade50
              : context.colorScheme.onPrimary,
          border: isAvailableOffline
              ? Border.all(color: Colors.red.shade300)
              : null,
        ),
        padding: EdgeInsets.all(context.minorSpace),
        child: AnimatedSize(
          duration: Durations.medium1,
          child: isDownloading
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress != null
                          ? "Downloading ${(progress * 100).toInt()}%"
                          : "Preparing…",
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.primary,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                        backgroundColor:
                            context.colorScheme.primary.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAvailableOffline
                          ? Icons.delete_outline_rounded
                          : Icons.offline_pin_outlined,
                      size: 12,
                      color: isAvailableOffline
                          ? Colors.red.shade600
                          : context.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isAvailableOffline ? "Remove from Offline" : "Browse Offline",
                      style: context.textTheme.bodySmall?.copyWith(
                        color: isAvailableOffline
                            ? Colors.red.shade600
                            : context.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

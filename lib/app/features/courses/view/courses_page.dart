import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/model/page_info.dart';
import 'package:lms/app/core/views/elements/connection_aware_widget.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/viewmodel/courses_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/offline_view_model.dart';
import 'package:lms/gen/assets.gen.dart';

class CoursesPage extends ConsumerWidget {
  const CoursesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: FlatAppBar(title: "Courses", enableBack: false),
      body: Padding(
        padding: EdgeInsets.all(context.smallSpace),
        child: PrimaryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: context.smallSpace,
                  right: context.smallSpace,
                  top: context.smallSpace,
                  bottom: context.minorSpace,
                ),
                child: Text(
                  "ACME Solutions Courses",
                  style: context.textTheme.titleLarge?.copyWith(
                    color: context.appColorScheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: ConnectionAwareWidget(
                  offlineChild: Consumer(
                    builder: (context, ref, child) {
                      final offlineVM = ref.watch(OfflineViewModel.provider);
                      final data = offlineVM.courses.data;
                      if (data == null || data.isEmpty) {
                        return const Center(child: Text("No courses found"));
                      }
                      return CoursesGrid(data: data);
                    },
                  ),
                  onlineChild: Consumer(
                    builder: (context, ref, child) {
                      final state = ref.watch(CoursesViewModel.provider);

                      return Column(
                        children: [
                          Expanded(
                            child: DataStateBuilder(
                              dataState: state.data,
                              builder: (context, data) {
                                if (data == null || data.isEmpty) {
                                  return const Center(
                                    child: Text("No courses found"),
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
    return ListView.builder(
      padding: EdgeInsets.all(context.smallSpace),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final course = data[index];
        return Padding(
          padding: EdgeInsets.only(bottom: context.smallSpace),
          child: SizedBox(
            height: 180,
            child: CourseCard(course: course),
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
        // All courses are freely accessible — navigate directly to course detail.
        Modular.to.pushNamed(
          CoursesModule.construct("${CoursesModule.detail}/${course.id}"),
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

/// "Save offline" / "Access Offline" button.
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
    return InkWell(
      onTap: () async {
        try {
          await offlineVM.download(course);
        } catch (e) {
          // ignore: use_build_context_synchronously
          Toast.error(context, e.toString());
        }
      },
      borderRadius: BorderRadius.circular(context.minorRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.minorRadius),
          color: context.colorScheme.onPrimary,
        ),
        padding: EdgeInsets.all(context.minorSpace),
        child: AnimatedSize(
          duration: Durations.medium1,
          child: isDownloading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(),
                )
              : Text(
                  isAvailableOffline ? "Access Offline" : "Save offline",
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.primary,
                  ),
                ),
        ),
      ),
    );
  }
}

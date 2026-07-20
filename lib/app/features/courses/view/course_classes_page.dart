import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/model/course_join_detail.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/view/content_view_page.dart';
import 'package:lms/app/features/courses/view/content_viewer/pdf_content_viewer.dart';
import 'package:lms/app/features/courses/view/content_viewer/video_content_viewer.dart';
import 'package:lms/app/features/courses/view/widgets/download_button.dart';
import 'package:lms/app/features/courses/viewmodel/course_join_detail_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/file_cache_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';
import 'package:lms/app/features/dashboard/view/app_drawer.dart';
import 'package:lms/app/features/courses/view/lms_app_bar.dart';
import 'package:lms/app_module.dart';
import 'package:url_launcher/url_launcher.dart';

bool _watchIsOnline(WidgetRef ref) {
  final isManualOffline = ref.watch(OfflineModeNotifier.provider);
  final connectionVM = ref.watch(InternetConnectionProvider.provider);
  ref.watch(SyncViewModel.provider);
  return !isManualOffline && connectionVM.isConnected;
}

const _detailPurple = Color(0xFF5756C9);
const _detailPurple2 = Color(0xFF775FE8);
const _detailInk = Color(0xFF172033);
const _detailMuted = Color(0xFF6D7587);
const _detailBackground = Color(0xFFF5F7FC);

class CourseClassesPage extends ConsumerStatefulWidget {
  const CourseClassesPage({super.key, this.courseId});
  final String? courseId;

  @override
  ConsumerState<CourseClassesPage> createState() => _CourseClassesPageState();
}

class _CourseClassesPageState extends ConsumerState<CourseClassesPage> {
  bool _redirectingUnauthorized = false;

  @override
  Widget build(BuildContext context) {
    final courseId = int.tryParse(widget.courseId ?? '') ?? 0;
    final state = ref.watch(CourseJoinDetailViewModel.provider(courseId));

    if (!_redirectingUnauthorized && _isUnauthorizedError(state.error)) {
      _redirectingUnauthorized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await ref.read(AuthStateNotifier.provider.notifier).logout();
        if (!mounted) return;
        Modular.to.navigate(AppModule.auth);
      });
    }

    return Scaffold(
      backgroundColor: _detailBackground,
      drawer: const AppDrawer(selectedLabel: 'Course Catalog'),
      appBar: LmsAppBar(
        onBack: () => _goBackToCatalog(context),
      ),
      body: _DetailBody(courseId: courseId, state: state),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.courseId, required this.state});

  final int courseId;
  final DataState<CourseJoinDetail> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state.state) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(
          child: CircularProgressIndicator(color: _detailPurple),
        );
      case DataProviderState.error:
        if (_isUnauthorizedError(state.error)) {
          return const Center(
            child: CircularProgressIndicator(color: _detailPurple),
          );
        }
        return _DetailError(
          message: state.error ?? 'Unable to load course details.',
          onRetry:
              () =>
                  ref
                      .read(
                        CourseJoinDetailViewModel.provider(courseId).notifier,
                      )
                      .fetch(),
        );
      case DataProviderState.data:
        final detail = state.data;
        if (detail == null) {
          return const _DetailError(message: 'No course detail found.');
        }
        return RefreshIndicator(
          color: _detailPurple,
          onRefresh:
              () =>
                  ref
                      .read(
                        CourseJoinDetailViewModel.provider(courseId).notifier,
                      )
                      .fetch(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth =
                  constraints.maxWidth >= 760 ? 720.0 : double.infinity;
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CourseHero(detail: detail),
                        Transform.translate(
                          offset: const Offset(0, -18),
                          child: _LaunchPanel(detail: detail),
                        ),
                        if (detail.participantGuide != null)
                          _InfoCard(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Consumer(
                                builder: (context, ref, _) {
                                  final isOnline = _watchIsOnline(ref);
                                  return OutlinedButton.icon(
                                    onPressed: isOnline
                                        ? () => _openUrl(detail.participantGuide!)
                                        : null,
                                    icon: isOnline
                                        ? const SizedBox.shrink()
                                        : const Icon(Icons.cloud_off_rounded, size: 15),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isOnline ? _detailPurple : _detailMuted,
                                      disabledForegroundColor: _detailMuted,
                                      side: BorderSide(
                                        color: isOnline
                                            ? const Color(0xFFD9D5FF)
                                            : const Color(0xFFE0E3E8),
                                      ),
                                      backgroundColor: isOnline
                                          ? const Color(0xFFFAF9FF)
                                          : const Color(0xFFF3F4F6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 13,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    label: Text(
                                      isOnline
                                          ? 'Download Participant Guide'
                                          : 'Internet required to download',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        _DescriptionCard(detail: detail),
                        _CourseImageCard(url: detail.logo),
                        _SkillsCard(skills: detail.skills),
                        _StructureCard(
                          items: detail.structures,
                          isEnrolled: detail.isEnrolled,
                          courseObjective: detail.objective,
                          courseTitle: detail.title,
                        ),
                        const _DetailFooter(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
    }
  }
}

void _goBackToCatalog(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  Modular.to.navigate(CoursesModule.construct(CoursesModule.root));
}

class _CourseHero extends StatelessWidget {
  const _CourseHero({required this.detail});
  final CourseJoinDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 10, 6, 0),
      padding: const EdgeInsets.fromLTRB(14, 34, 14, 54),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_detailPurple, _detailPurple2]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 10),
          if (detail.isEnrolled && detail.allowRating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .15),
                border: Border.all(color: Colors.white.withValues(alpha: .36)),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text(
                'Add Rating',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LaunchPanel extends StatefulWidget {
  const _LaunchPanel({required this.detail});
  final CourseJoinDetail detail;

  @override
  State<_LaunchPanel> createState() => _LaunchPanelState();
}

class _LaunchPanelState extends State<_LaunchPanel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.detail.launchDate != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final launchDate = detail.launchDate;
    Duration? remaining;
    if (launchDate != null) {
      final diff = launchDate.difference(DateTime.now());
      remaining = diff.isNegative ? Duration.zero : diff;
    }

    return _InfoCard(
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 28),
      child: Column(
        children: [
          const Text(
            'LAUNCHES IN',
            style: TextStyle(
              color: _detailMuted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _timeEntry(remaining?.inDays ?? 0, 'DAYS'),
              _timeEntry((remaining?.inHours ?? 0) % 24, 'HRS'),
              _timeEntry((remaining?.inMinutes ?? 0) % 60, 'MIN'),
              _timeEntry((remaining?.inSeconds ?? 0) % 60, 'SEC'),
            ],
          ),
          const SizedBox(height: 26),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.fromLTRB(17, 8, 10, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F3FF),
                border: Border.all(color: const Color(0xFFE5DFFF)),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    detail.launchStatus.toUpperCase(),
                    style: const TextStyle(
                      color: _detailPurple,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (detail.progressPercentage > 0) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        value: detail.progressPercentage,
                        strokeWidth: 2.5,
                        color: _detailPurple,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (detail.learningPath != null) ...[
            const SizedBox(height: 26),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F1FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Learning Path: ',
                    style: TextStyle(
                      color: _detailInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDF3FF),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      detail.learningPath!,
                      style: const TextStyle(color: Color(0xFF0877A8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (detail.isEnrolled) {
                  _showCancelConfirmationDialog(context);
                }
              },
              icon: const Icon(Icons.app_registration_rounded, size: 18),
              label: Text(detail.primaryAction),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(47),
                backgroundColor: _detailPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeEntry(int value, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: _TimeBox(value: value, label: label),
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.detail});
  final CourseJoinDetail detail;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Course Description'),
          if (detail.description.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              detail.description,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _detailMuted,
                height: 1.55,
                fontSize: 16,
              ),
            ),
          ],
          const SizedBox(height: 28),
          const Divider(color: Color(0xFFECEFF4)),
          const SizedBox(height: 16),
          const _SectionTitle('Learning Objectives'),
          if (detail.objective.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              detail.objective,
              style: const TextStyle(
                color: _detailMuted,
                height: 1.55,
                fontSize: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CourseImageCard extends StatelessWidget {
  const _CourseImageCard({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 160,
        child:
            url == null
                ? const _ImageFallback()
                : Image.network(
                  url!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _ImageFallback(),
                ),
      ),
    );
  }
}

class _SkillsCard extends StatelessWidget {
  const _SkillsCard({required this.skills});
  final List<String> skills;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      margin: const EdgeInsets.fromLTRB(12, 34, 12, 78),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Skills or Behaviors'),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  skills
                      .map(
                        (skill) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F3FF),
                            border: Border.all(color: const Color(0xFFE5DFFF)),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(
                              color: _detailPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StructureCard extends StatelessWidget {
  const _StructureCard({
    required this.items,
    required this.isEnrolled,
    required this.courseObjective,
    required this.courseTitle,
  });
  final List<CourseStructureItem> items;
  final bool isEnrolled;
  final String courseObjective;
  final String courseTitle;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Course Structure'),
          const SizedBox(height: 28),
          if (items.isEmpty)
            const Text(
              'No course structure is available.',
              style: TextStyle(color: _detailMuted),
            )
          else
            for (final item in items) ...[
              _StructureItemCard(
                item: item,
                isEnrolled: isEnrolled,
                courseObjective: courseObjective,
                courseTitle: courseTitle,
              ),
              if (item != items.last) const SizedBox(height: 20),
            ],
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: _detailPurple,
              side: const BorderSide(color: _detailPurple),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            child: Text('${items.length} Per Page'),
          ),
        ],
      ),
    );
  }
}

class _StructureItemCard extends StatelessWidget {
  const _StructureItemCard({
    required this.item,
    required this.isEnrolled,
    required this.courseObjective,
    required this.courseTitle,
  });
  final CourseStructureItem item;
  final bool isEnrolled;
  final String courseObjective;
  final String courseTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEAEDEF)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              color: _detailInk,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (item.subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.subtitle,
              style: const TextStyle(color: Color(0xFF9AA4B5), fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFECEFF4)),
          const SizedBox(height: 13),
          if (item.nextSession.isNotEmpty) ...[
            Text(
              'Next Session: ${item.nextSession}',
              style: const TextStyle(
                color: _detailMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (item.status.isNotEmpty) ...[
            _StatusChip(status: item.status),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 1),
          const Divider(color: Color(0xFFECEFF4)),
          if (item.showDetails || item.showAction || item.isEnrolledInClass) ...[
            const SizedBox(height: 18),
            if (item.showDetails)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showClassDetails(context, courseTitle, courseObjective, item),
                  icon: const Icon(Icons.info_rounded, size: 16),
                  label: const Text('Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _detailInk,
                    side: const BorderSide(color: Color(0xFFDDE2EA)),
                    minimumSize: const Size.fromHeight(39),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            // Registered Virtual Class: Attend Class + optional recordings + Cancel
            if (item.typeCode == '3' && item.isEnrolledInClass) ...[
              const SizedBox(height: 15),
              if (item.contentUrl != null) ...[
                _OnlineActionButton(
                  icon: Icons.send_rounded,
                  label: 'Attend Class',
                  onPressed: () => _openUrl(item.contentUrl!),
                ),
                const SizedBox(height: 10),
              ],
              // Recordings — Watch (browser) + Download (offline)
              for (final recordingUrl in item.recordingUrls) ...[
                _OnlineActionButton(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Watch Recording',
                  onPressed: () => _openUrl(recordingUrl),
                ),
                const SizedBox(height: 8),
                DownloadButton(
                  url: recordingUrl,
                  label: 'Recording',
                  icon: Icons.videocam_rounded,
                  courseClass: null,
                  fullWidth: true,
                  builder: (ctx, file) => VideoContentViewer(file: file),
                ),
                const SizedBox(height: 10),
              ],
              _OnlineActionButton(
                icon: Icons.cancel_outlined,
                label: 'Cancel Registration',
                onPressed: () => _showCancelConfirmationDialog(context),
              ),
            ] else if (item.typeCode == '4') ...[
              // Watch Video — "Watch" opens browser (handles HLS/VP9 on iOS);
              // "Download" is handled by DownloadButton below for offline MP4.
              const SizedBox(height: 15),
              if (item.contentUrl != null)
                _OnlineActionButton(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Watch Video',
                  onPressed: () => _openUrl(item.contentUrl!),
                ),
            ] else ...[
              if (item.showDetails && item.showAction) const SizedBox(height: 15),
              if (item.showAction)
                _EnrollActionButton(
                  isEnrolled: isEnrolled,
                  icon: _actionIcon(item.icon),
                  label: item.actionLabel,
                  item: item,
                ),
            ],
            if (item.downloadUrl != null) ...[
              const SizedBox(height: 10),
              if (item.typeCode == '4')
                DownloadButton(
                  url: item.downloadUrl,
                  label: _downloadLabel(item.typeCode),
                  icon: Icons.videocam_rounded,
                  courseClass: null,
                  fullWidth: true,
                  builder: (ctx, file) => VideoContentViewer(file: file),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: DownloadButton(
                    url: item.downloadUrl,
                    label: _downloadLabel(item.typeCode),
                    icon: Icons.picture_as_pdf_rounded,
                    courseClass: null,
                    builder: (ctx, file) => PdfContentViewer(file: file),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// A full-width elevated action button that disables itself with a
/// "cloud off" state whenever offline, since [onPressed] always performs a
/// network action (opening a link, launching content, etc.).
class _OnlineActionButton extends ConsumerWidget {
  const _OnlineActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = _watchIsOnline(ref);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isOnline ? onPressed : null,
        icon: Icon(isOnline ? icon : Icons.cloud_off_rounded, size: 17),
        label: Text(isOnline ? label : 'Internet required'),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: isOnline ? _detailPurple : Colors.grey.shade400,
          disabledBackgroundColor: Colors.grey.shade400,
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(39),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

/// The generic course-structure action button (e.g. "Agreement", "Launch
/// Web Application"). Unlike [_OnlineActionButton], the not-enrolled path
/// only opens a local dialog, so it stays enabled offline — only the
/// enrolled/network-performing path gets disabled when offline.
class _EnrollActionButton extends ConsumerWidget {
  const _EnrollActionButton({
    required this.isEnrolled,
    required this.icon,
    required this.label,
    required this.item,
  });
  final bool isEnrolled;
  final IconData icon;
  final String label;
  final CourseStructureItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isEnrolled) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showNotEnrolledDialog(context),
          icon: Icon(icon, size: 17),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: _detailPurple,
            minimumSize: const Size.fromHeight(39),
            elevation: 0,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }
    return _OnlineActionButton(
      icon: icon,
      label: label,
      onPressed: () => _handleClassAction(context, item),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(12, 0, 12, 24),
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: _detailPurple,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _detailInk,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9FF),
        border: Border.all(color: const Color(0xFFE5DFFF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: _detailPurple,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _detailMuted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0ECFF),
      alignment: Alignment.center,
      child: const Icon(Icons.school_outlined, color: _detailPurple, size: 78),
    );
  }
}

class _DetailFooter extends StatelessWidget {
  const _DetailFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: const Row(
        children: [
          Text('Terms of Use', style: TextStyle(color: Color(0xFF444A57))),
          SizedBox(width: 28),
          Text('Your Profile', style: TextStyle(color: Color(0xFF444A57))),
          SizedBox(width: 28),
          Text(
            'Support',
            style: TextStyle(
              color: Color(0xFF444A57),
              decoration: TextDecoration.underline,
            ),
          ),
          Spacer(),
          Text(
            'in',
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _detailMuted, size: 54),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

IconData _actionIcon(CourseStructureIcon icon) {
  switch (icon) {
    case CourseStructureIcon.register:       return Icons.how_to_reg_rounded;
    case CourseStructureIcon.video:          return Icons.videocam_rounded;
    case CourseStructureIcon.article:        return Icons.article_rounded;
    case CourseStructureIcon.webpage:        return Icons.language_rounded;
    case CourseStructureIcon.discussionBoard: return Icons.forum_rounded;
    case CourseStructureIcon.tasks:          return Icons.task_alt_rounded;
    case CourseStructureIcon.coaches:        return Icons.people_rounded;
    case CourseStructureIcon.insights:       return Icons.bar_chart_rounded;
    case CourseStructureIcon.certification:  return Icons.workspace_premium_rounded;
    case CourseStructureIcon.discussionGuru: return Icons.chat_rounded;
    case CourseStructureIcon.link:           return Icons.link_rounded;
    case CourseStructureIcon.agreement:      return Icons.edit_rounded;
    case CourseStructureIcon.details:        return Icons.info_rounded;
  }
}

void _handleClassAction(BuildContext context, CourseStructureItem item) {
  final url = item.contentUrl;
  switch (item.typeCode) {
    case '4':
      // Watch Video â€” DownloadButton handles this; action button is hidden for type '4'.
      break;
    case '5': // Read Article
    case '15': // Peer Coaching (PDF)
    case '19': // Agreement (PDF)
      if (url == null) return;
      ContentViewPage.show(
        context: context,
        courseClass: null,
        child: PdfContentViewer(file: FileCacheState(url: url)),
      );
      break;
    default:
      if (url != null) _openUrl(url);
  }
}

String _downloadLabel(String typeCode) {
  switch (typeCode) {
    case '4': return 'Video';
    case '5': return 'Article';
    case '15': return 'Guide';
    case '19': return 'Agreement';
    default: return 'File';
  }
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

bool _isUnauthorizedError(String? error) {
  final value = error?.toLowerCase() ?? '';
  return value.startsWith('unauthorized') ||
      value.contains('invalid credentials') ||
      value.contains('status code of 401') ||
      value.contains(' 401');
}

void _showNotEnrolledDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      content: const Text(
        'You are not enrolled for this course. Click the Enroll Now button at the top of this page to continue.',
        style: TextStyle(color: _detailMuted, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: _detailPurple),
          child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

void _showCancelConfirmationDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Confirm Cancellation',
        style: TextStyle(
          color: _detailInk,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
      content: const Text(
        'Would you like to cancel your registration for this course?',
        style: TextStyle(color: _detailMuted, height: 1.5),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: _detailInk,
            side: const BorderSide(color: Color(0xFFCBCBCB)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          child: const Text(
            'No, Keep It',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: _detailPurple,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          child: const Text(
            'Yes, Cancel',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

void _showClassDetails(
  BuildContext context,
  String courseTitle,
  String courseObjective,
  CourseStructureItem item,
) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.all(20),
      child: _ClassDetailsDialog(
        courseTitle: courseTitle,
        courseObjective: courseObjective,
        item: item,
      ),
    ),
  );
}

class _ClassDetailsDialog extends StatelessWidget {
  const _ClassDetailsDialog({
    required this.courseTitle,
    required this.courseObjective,
    required this.item,
  });

  final String courseTitle;
  final String courseObjective;
  final CourseStructureItem item;

  @override
  Widget build(BuildContext context) {
    final typeName = item.subtitle.length > 2
        ? item.subtitle.substring(1, item.subtitle.length - 1)
        : '';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 540),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            decoration: const BoxDecoration(
              color: _detailPurple,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    courseTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (typeName.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .35),
                      ),
                    ),
                    child: Text(
                      typeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (courseObjective.isNotEmpty) ...[
                    const _DialogLabel('OBJECTIVE'),
                    const SizedBox(height: 8),
                    Text(
                      courseObjective,
                      style: const TextStyle(color: _detailMuted, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFECEFF4)),
                    const SizedBox(height: 16),
                  ],
                  if (item.description.isNotEmpty) ...[
                    const _DialogLabel('DESCRIPTION'),
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      style: const TextStyle(color: _detailMuted, height: 1.5),
                    ),
                  ],
                  if (item.learningEvents.isNotEmpty) ...[
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFECEFF4)),
                      const SizedBox(height: 16),
                    ],
                    const _DialogLabel('SCHEDULE'),
                    const SizedBox(height: 12),
                    for (final event in item.learningEvents)
                      _LearningEventCard(event: event),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _detailMuted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _LearningEventCard extends StatelessWidget {
  const _LearningEventCard({required this.event});
  final LearningEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFECEFF4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ScheduleField(
                  label: 'START',
                  value: _formatDateTime(event.startDate, event.startTime),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ScheduleField(
                  label: 'END',
                  value: _formatDateTime(event.endDate, event.endTime),
                ),
              ),
            ],
          ),
          if (event.instructor.isNotEmpty || event.location.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFECEFF4)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.instructor.isNotEmpty)
                  Expanded(
                    child: _ScheduleField(
                      label: 'INSTRUCTOR',
                      value: event.instructor,
                    ),
                  ),
                if (event.instructor.isNotEmpty && event.location.isNotEmpty)
                  const SizedBox(width: 16),
                if (event.location.isNotEmpty)
                  Expanded(
                    child: _ScheduleField(
                      label: 'LOCATION',
                      value: event.location,
                    ),
                  ),
              ],
            ),
          ],
          if (event.instructions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFECEFF4)),
            const SizedBox(height: 12),
            _ScheduleField(label: 'INSTRUCTIONS', value: event.instructions),
          ],
        ],
      ),
    );
  }
}

class _ScheduleField extends StatelessWidget {
  const _ScheduleField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _detailMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? 'â€”' : value,
          style: const TextStyle(
            color: _detailInk,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isCompleted = status.toLowerCase() == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFE8F5E9) : const Color(0xFFEEECFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isCompleted ? const Color(0xFF2E7D32) : _detailPurple,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _formatDateTime(String date, String time) {
  if (date == '0000-00-00' || date.isEmpty) return _formatTime(time);
  final dateTime = DateTime.tryParse('${date}T$time');
  if (dateTime == null) return '$date $time'.trim();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final month = months[dateTime.month - 1];
  final hour = dateTime.hour;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final amPm = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$month ${dateTime.day}\n$hour12:$minute $amPm';
}

String _formatTime(String time) {
  if (time.isEmpty) return '';
  final parts = time.split(':');
  if (parts.length < 2) return time;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = parts[1].padLeft(2, '0');
  final amPm = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$hour12:$minute $amPm';
}


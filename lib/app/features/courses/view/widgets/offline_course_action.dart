import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/viewmodel/offline_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _muted = FigmaTokens.noteBodyText;

/// Bookmark-style button for saving/removing a course's offline copy and
/// showing its download progress. Reusable on any screen that lists
/// courses (catalog, dashboard, my courses, enrolled/completed/required,
/// development plan) so offline downloads aren't only reachable from one
/// screen.
class OfflineCourseButton extends ConsumerWidget {
  const OfflineCourseButton({
    super.key,
    required this.course,
    this.iconSize = 21,
  });
  final Course course;

  /// Icon size inside the round shell; total diameter is iconSize + 14
  /// (7px padding each side). Default 21 -> 35px; the course catalog
  /// passes 22 -> 36px to match its 36x36 .dev-plan-action button.
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineVM = ref.watch(OfflineViewModel.provider);
    final isManualOffline = ref.watch(OfflineModeNotifier.provider);
    final connectionVM = ref.watch(InternetConnectionProvider.provider);
    final isOnline = !isManualOffline && connectionVM.isConnected;

    return _OfflineCourseAction(
      isOnline: isOnline,
      isSavedOffline: offlineVM.isAvailable(course),
      isDownloading: offlineVM.isDownloading(course),
      progress: offlineVM.downloadProgress(course),
      iconSize: iconSize,
      onSave: () => offlineVM.download(course),
      onRemove: () => offlineVM.removeOffline(course),
    );
  }
}

class _OfflineCourseAction extends StatelessWidget {
  const _OfflineCourseAction({
    required this.isOnline,
    required this.isSavedOffline,
    required this.isDownloading,
    required this.progress,
    required this.iconSize,
    required this.onSave,
    required this.onRemove,
  });

  final bool isOnline;
  final bool isSavedOffline;
  final bool isDownloading;
  final double? progress;
  final double iconSize;
  final VoidCallback onSave;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      return _roundActionShell(
        tooltip: 'Saving course offline',
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 2.4,
            color: _purple,
          ),
        ),
      );
    }

    if (isSavedOffline) {
      return _roundActionButton(
        tooltip: 'Remove offline copy',
        icon: Icons.bookmark_remove_outlined,
        color: const Color(0xFF24A35A),
        onTap: onRemove,
      );
    }

    return _roundActionButton(
      tooltip: isOnline ? 'Save for offline' : 'Connect to save offline',
      // Solid (bold) glyph so this icon's weight matches the dev-plan
      // +/- button's solid FontAwesome icons.
      icon: isOnline ? FontAwesomeIcons.bookmark : Icons.wifi_off_rounded,
      color: isOnline ? _purple : _muted,
      onTap: isOnline ? onSave : null,
    );
  }

  Widget _roundActionButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return _roundActionShell(
      tooltip: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
  }

  Widget _roundActionShell({required String tooltip, required Widget child}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 5,
        shape: const CircleBorder(),
        child: Padding(
          padding: child is InkWell ? EdgeInsets.zero : const EdgeInsets.all(8),
          child: child,
        ),
      ),
    );
  }
}

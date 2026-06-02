import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/viewmodel/roaster_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders a tappable chip that opens an external URL.
/// Matches the visual style of [ClassStatusChip] (pill shape, same text size).
///
/// Returns an empty widget when [url] is null or empty.
class LinkButton extends ConsumerWidget {
  const LinkButton({
    super.key,
    required this.icon,
    required this.label,
    required this.url,
    required this.courseClass,
  });

  final IconData icon;
  final String label;
  final String? url;
  final CourseClass? courseClass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (url == null || url!.isEmpty) return const SizedBox.shrink();

    final isManualOffline = ref.watch(OfflineModeNotifier.provider);
    final connectionVM = ref.watch(InternetConnectionProvider.provider);
    ref.watch(SyncViewModel.provider);

    final isOnline = !isManualOffline && connectionVM.isConnected;

    if (!isOnline) {
      // ── Offline: disabled chip ────────────────────────────────────────────
      return Tooltip(
        message: "Internet required — not available offline",
        child: _ChipButton(
          icon: icon,
          label: label,
          trailing: const Icon(Icons.cloud_off, size: 12, color: Colors.grey),
          onTap: null,
        ),
      );
    }

    // ── Online: tappable chip ─────────────────────────────────────────────────
    return _ChipButton(
      icon: icon,
      label: label,
      onTap: () async {
        if (courseClass != null) {
          ref
              .read(RoasterViewModel.provider(courseClass!.courseId).notifier)
              .markAsRead(courseClass!);
        }
        final uri = Uri.tryParse(url!);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open link.')),
            );
          }
        }
      },
    );
  }
}

/// Shared chip-style button used by [LinkButton] and exported for reuse.
class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled ? Colors.grey.shade200 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled ? Colors.grey.shade400 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: enabled ? Colors.black87 : Colors.grey,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: enabled ? Colors.black87 : Colors.grey,
                  ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/viewmodel/roaster_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tappable chip that opens an external URL.
/// Styled identically to [ClassStatusChip] ("Registered" chip).
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
      return Tooltip(
        message: "Internet required — not available offline",
        child: actionChip(
          context: context,
          icon: icon,
          label: label,
          onPressed: null,
          trailing: const Icon(Icons.cloud_off, size: 12, color: Colors.grey),
        ),
      );
    }

    return actionChip(
      context: context,
      icon: icon,
      label: label,
      onPressed: () async {
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

/// Shared chip widget used by [LinkButton] and [DownloadButton].
/// Matches the visual style of the "Registered" [Chip] exactly.
Widget actionChip({
  required BuildContext context,
  required IconData icon,
  required String label,
  required VoidCallback? onPressed,
  Widget? trailing,
}) {
  return ActionChip(
    onPressed: onPressed,
    avatar: Icon(icon, size: 14),
    label: trailing == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 4),
              trailing,
            ],
          ),
    labelStyle: const TextStyle(fontSize: 12),
    labelPadding: const EdgeInsets.only(left: 2, right: 4),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    side: BorderSide.none,
  );
}

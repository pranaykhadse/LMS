import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/viewmodel/roaster_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tappable chip that opens an external URL.
/// Same shape/size/padding as [ClassStatusChip]; uses purple outlined style.
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
    final primary = context.appColorScheme.primary;

    if (!isOnline) {
      return Tooltip(
        message: "Internet required — not available offline",
        child: appActionChip(
          icon: icon,
          label: label,
          fgColor: Colors.grey,
          bgColor: Colors.transparent,
          borderColor: Colors.grey,
          onPressed: null,
          trailing: const Icon(Icons.cloud_off, size: 12, color: Colors.grey),
        ),
      );
    }

    return appActionChip(
      icon: icon,
      label: label,
      fgColor: primary,
      bgColor: Colors.transparent,
      borderColor: primary,
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

/// Shared chip widget matching [ClassStatusChip] size/shape with custom colors.
/// Used by [LinkButton] and [DownloadButton].
Widget appActionChip({
  required IconData icon,
  required String label,
  required Color fgColor,
  required Color bgColor,
  required Color borderColor,
  required VoidCallback? onPressed,
  Widget? trailing,
}) {
  return ActionChip(
    onPressed: onPressed,
    backgroundColor: bgColor,
    side: BorderSide(color: borderColor),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    labelPadding: const EdgeInsets.only(left: 2, right: 4),
    avatar: Icon(icon, size: 14, color: fgColor),
    label: trailing == null
        ? Text(label,
            style: TextStyle(
                color: fgColor, fontSize: 12, fontWeight: FontWeight.w600))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      color: fgColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              trailing,
            ],
          ),
  );
}

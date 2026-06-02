import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/viewmodel/roaster_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders a tappable button that opens an external URL.
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

    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    const textStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 12);

    if (!isOnline) {
      return Tooltip(
        message: "Internet required — not available offline",
        child: OutlinedButton.icon(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey,
            side: const BorderSide(color: Colors.grey),
            padding: padding,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: textStyle,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: Icon(icon, size: 16),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 4),
              const Icon(Icons.cloud_off, size: 12, color: Colors.grey),
            ],
          ),
        ),
      );
    }

    return OutlinedButton.icon(
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
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.appColorScheme.primary,
        side: BorderSide(color: context.appColorScheme.primary),
        padding: padding,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: textStyle,
        shape: const StadiumBorder(),
      ),
    );
  }
}

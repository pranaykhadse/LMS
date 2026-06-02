import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
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
///
/// Netflix-style offline behaviour:
///   • Online  → button enabled, tapping opens the URL in the browser.
///   • Offline → button shown as disabled with a "Not available offline" tooltip.
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
  // Nullable: course-level link buttons have no lesson context.
  final CourseClass? courseClass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (url == null || url!.isEmpty) return const SizedBox.shrink();

    // Watch all relevant providers so the button rebuilds immediately on any
    // connectivity change — no StreamBuilder needed.
    final isManualOffline = ref.watch(OfflineModeNotifier.provider);
    final connectionVM = ref.watch(InternetConnectionProvider.provider);
    // SyncViewModel notifies on physical connection changes.
    ref.watch(SyncViewModel.provider);

    final isOnline = !isManualOffline && connectionVM.isConnected;

    final padding = defaultTargetPlatform == TargetPlatform.macOS
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    if (!isOnline) {
      // ── Offline: greyed-out disabled button ───────────────────────────
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
            textStyle: context.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          icon: Icon(icon, size: 18),
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

    // ── Online: normal tappable button ────────────────────────────────────
    return OutlinedButton.icon(
      onPressed: () async {
        // Mark the lesson complete when the user taps the link.
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
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.appColorScheme.primary,
        side: BorderSide(color: context.appColorScheme.primary),
        padding: padding,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: context.textTheme.bodySmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

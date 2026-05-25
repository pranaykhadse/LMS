import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
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
  // Nullable: course-level link buttons (e.g. Wrap Methodology) have no lesson.
  final CourseClass? courseClass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (url == null || url!.isEmpty) return const SizedBox.shrink();

    final connectionVM = ref.watch(InternetConnectionProvider.provider);
    final isManualOffline = ref.watch(OfflineModeNotifier.provider);

    return StreamBuilder<bool>(
      stream: connectionVM.connectionStream,
      initialData: connectionVM.isConnected,
      builder: (context, snapshot) {
        // Effectively offline when the manual toggle is ON OR no physical internet.
        final isOnline = !isManualOffline &&
            (snapshot.data ?? connectionVM.isConnected);

        if (!isOnline) {
          // ── Offline: show a greyed-out, disabled-looking button ──────────
          return Tooltip(
            message: "Internet required — not available offline",
            child: OutlinedButton.icon(
              onPressed: null, // disabled
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                side: const BorderSide(color: Colors.grey),
              ),
              icon: Icon(icon),
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

        // ── Online: normal tappable button ────────────────────────────────
        return OutlinedButton.icon(
          onPressed: () async {
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
          icon: Icon(icon),
          label: Text(label),
        );
      },
    );
  }
}

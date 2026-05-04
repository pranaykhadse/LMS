import 'package:flutter/material.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders a tappable button that opens an external URL.
/// Returns an empty widget when [url] is null or empty.
class LinkButton extends StatelessWidget {
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
  final CourseClass courseClass;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return const SizedBox.shrink();

    return OutlinedButton(
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: context.minorSpace,
        children: [Icon(icon), Text(label)],
      ),
    );
  }
}

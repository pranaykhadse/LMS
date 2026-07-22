import 'package:flutter/material.dart';
import 'package:lms/app/features/dashboard/view/account_settings_page.dart';

const _footerLink = Color(0xFF5756C9);
const _footerMuted = Color(0xFF98A2B3);

/// Matches the website's global footer (Terms of Use / Your Profile /
/// Support + LinkedIn) — shown at the bottom of every main screen.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          const _FooterLink(label: 'Terms of Use'),
          _FooterLink(
            label: 'Your Profile',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountSettingsPage()),
            ),
          ),
          const _FooterLink(label: 'Support'),
          const _LinkedInBadge(),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: onTap != null ? _footerLink : _footerMuted,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          decoration: onTap != null ? TextDecoration.underline : null,
          decorationColor: _footerLink,
        ),
      ),
    );
  }
}

class _LinkedInBadge extends StatelessWidget {
  const _LinkedInBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0A66C2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'in',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

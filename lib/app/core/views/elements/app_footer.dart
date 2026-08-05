import 'package:flutter/material.dart';
import 'package:lms/app/features/dashboard/view/account_settings_page.dart';

const _footerText = Color(0xFF667085);
const _footerBorder = Color(0xFFE4E7EC);

/// Matches the website's global footer (Terms of Use / Your Profile /
/// Support + LinkedIn) — shown at the bottom of every main screen.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1, color: _footerBorder),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 24,
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
                ],
              ),
              const _LinkedInBadge(),
            ],
          ),
        ),
      ],
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
        style: const TextStyle(color: _footerText, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _LinkedInBadge extends StatelessWidget {
  const _LinkedInBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFF2F4F7),
        shape: BoxShape.circle,
      ),
      child: const Text(
        'in',
        style: TextStyle(
          color: _footerText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

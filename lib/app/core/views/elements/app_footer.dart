import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/features/dashboard/view/account_settings_page.dart';

const _footerText = Color(0xFF6B7280);
const _footerBorder = Color(0xFFE4E7EC);
const _linkedInBg = Color(0xFFE2E8F0);

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
        style: GoogleFonts.inter(color: _footerText, fontSize: 14),
      ),
    );
  }
}

class _LinkedInBadge extends StatelessWidget {
  const _LinkedInBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: _linkedInBg,
        shape: BoxShape.circle,
      ),
      child: Text(
        'in',
        style: GoogleFonts.inter(
          color: _footerText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

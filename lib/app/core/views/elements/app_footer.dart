import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/features/courses/view/content_viewer/in_app_webview_page.dart';
import 'package:lms/app/features/dashboard/view/account_settings_page.dart';
import 'package:url_launcher/url_launcher.dart';

const _footerText = Color(0xFF6B7280);
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
        // Design ref: flex ... gap-3 py-3 border-t border-gray-200
        // text-[13px] text-gray-400
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  _FooterLink(
                    label: 'Terms of Use',
                    onTap: () => InAppWebViewPage.show(
                      context,
                      url: 'https://www.iubenda.com/terms-and-conditions/26898975',
                      title: 'Terms of Use',
                    ),
                  ),
                  _FooterLink(
                    label: 'Your Profile',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AccountSettingsPage()),
                    ),
                  ),
                  _FooterLink(
                    label: 'Support',
                    // Bare mailto: opens a blank compose window in whichever
                    // mail app/account the user already has signed in as
                    // the OS default - not something we can address further.
                    onTap: () => launchUrl(Uri.parse('mailto:')),
                  ),
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
        style: GoogleFonts.inter(color: _footerText, fontSize: 13),
      ),
    );
  }
}

// Design ref: plain icon-only link (text-gray-500, hover:text-[#0077b5]),
// no circular badge background - <Linkedin size={16} />. Material Icons has
// no bundled LinkedIn glyph, so this keeps the "in" mark but drops the
// circle/fill this had before to match the reference's plain-icon treatment.
class _LinkedInBadge extends StatelessWidget {
  const _LinkedInBadge();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(
        Uri.parse('https://www.linkedin.com/company/looking-forward-consulting'),
        mode: LaunchMode.externalApplication,
      ),
      child: SizedBox(
        width: 16,
        height: 16,
        child: Center(
          child: Text(
            'in',
            style: GoogleFonts.inter(
              color: _footerText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

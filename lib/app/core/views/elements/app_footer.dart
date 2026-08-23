import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/features/courses/view/content_viewer/in_app_webview_page.dart';
import 'package:lms/app/features/dashboard/view/account_settings_page.dart';
import 'package:url_launcher/url_launcher.dart';

// Design ref: a.hover:text-gray-600 - the footer links' hover color.
const _footerTextHover = Color(0xFF1A1A2E);

const _footerText = Color(0xFFAF99A1);
// Design ref (phone): footer link/icon color is a lighter gray than
// desktop's _footerText.
const _footerTextPhone = Color(0xFF99A1AF);
const _footerBorder = Color(0xFFE4E7EC);

/// Matches the website's global footer (Terms of Use / Your Profile /
/// Support + LinkedIn) — shown at the bottom of every main screen.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final color = isTablet ? _footerText : _footerTextPhone;
    final links = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        _FooterLink(
          label: 'Terms of Use',
          color: color,
          onTap: () => InAppWebViewPage.show(
            context,
            url: 'https://www.iubenda.com/terms-and-conditions/26898975',
            title: 'Terms of Use',
          ),
        ),
        _FooterLink(
          label: 'Your Profile',
          color: color,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AccountSettingsPage()),
          ),
        ),
        _FooterLink(
          label: 'Support',
          color: color,
          // Bare mailto: opens a blank compose window in whichever
          // mail app/account the user already has signed in as
          // the OS default - not something we can address further.
          onTap: () => launchUrl(Uri.parse('mailto:')),
        ),
      ],
    );
    final linkedIn = _LinkedInBadge(color: color);

    return Column(
      children: [
        const Divider(height: 1, color: _footerBorder),
        // Design ref: flex ... gap-3 py-3 border-t border-gray-200
        // text-[13px] text-gray-400. Phone: links + icon stack centered
        // instead of a space-between row, and the gutter matches the
        // page's own outer padding (12px) instead of a flat 20px.
        Padding(
          padding: EdgeInsets.fromLTRB(isTablet ? 20 : 12, 12, isTablet ? 20 : 12, 12),
          child: isTablet
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [links, linkedIn],
                )
              : Column(
                  children: [
                    links,
                    const SizedBox(height: 12),
                    linkedIn,
                  ],
                ),
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.color, this.onTap});
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovering) => InkWell(
        onTap: onTap,
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: hovering ? _footerTextHover : color,
            fontSize: 13,
            height: 19.5 / 13,
          ),
        ),
      ),
    );
  }
}

// Design ref: plain icon-only link (text-gray-500, hover:text-[#0077b5]),
// no circular badge background - <Linkedin size={16} />, 16x16 measured.
class _LinkedInBadge extends StatelessWidget {
  const _LinkedInBadge({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(
        Uri.parse('https://www.linkedin.com/company/looking-forward-consulting'),
        mode: LaunchMode.externalApplication,
      ),
      child: Icon(LucideIcons.linkedin, size: 16, color: color),
    );
  }
}

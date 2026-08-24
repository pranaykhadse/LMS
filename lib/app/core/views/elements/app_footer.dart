import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/features/courses/view/content_viewer/in_app_webview_page.dart';
import 'package:lms/app/features/dashboard/view/account_settings_page.dart';
import 'package:url_launcher/url_launcher.dart';

// Design ref: a.hover:text-gray-600 - the footer links' hover color.
const _footerTextHover = Color(0xFF4B5563); // gray-600
// Desktop/tablet footer text
const _footerText = Color(0xFF9CA3AF); // gray-400
// Mobile footer text — gray-400 = #9CA3AF (matches reference)
const _footerTextPhone = Color(0xFF9CA3AF); // gray-400
// LinkedIn icon on mobile — gray-500 = #6B7280
const _footerLinkedInPhone = Color(0xFF6B7280);
const _footerBorder = Color(0xFFE5E7EB); // gray-200

/// Matches the website's global footer (Terms of Use / Your Profile /
/// Support + LinkedIn) — shown at the bottom of every main screen.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final color = isTablet ? _footerText : _footerTextPhone;
    // LinkedIn icon: gray-500 = #6B7280 on all sizes
    final linkedInColor = isTablet ? _footerLinkedInPhone : _footerLinkedInPhone;
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
    final linkedIn = _LinkedInBadge(color: linkedInColor);

    return Column(
      children: [
        const Divider(height: 1, color: _footerBorder),
        // py-3 (12px) top/bottom, no horizontal padding on any size —
        // outer page wrapper provides horizontal spacing.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/features/courses/view/content_viewer/in_app_webview_page.dart';
import 'package:lms/app/features/dashboard/view/account_settings_page.dart';
import 'package:url_launcher/url_launcher.dart';

// CSS ref: #footer .footer-menu ul li a — color var(--text-secondary,
// #6b7280) !important — this ID-qualified rule (modern-course-cards.css)
// wins over the plain `.footer-menu ul li a` rule in bluetheme-layout.css
// (#6A7282/13px) despite loading first, since the ID selector is more
// specific. Hover: #footer ... a:hover — color var(--primary-first,
// #693D94) !important.
const _footerText = Color(0xFF6B7280);
const _footerTextHover = Color(0xFF693D94);
// CSS ref: footer#footer — border-top: 1px solid var(--card-border,
// #E5E7EB), background: var(--bg-light, #F4F5F7).
const _footerBorder = Color(0xFFE5E7EB);
const _footerBg = Color(0xFFF4F5F7);
// CSS ref: #footer .social-link ul li a — 36x36 circle, background
// var(--border-light, #f3f4f6). #footer .social-link ul li a i — color
// var(--close-btn-gray, #99A1AF), font-size 18px. The :hover rule sets the
// identical bg/color — i.e. deliberately no visible hover change.
const _socialBadgeBg = Color(0xFFF3F4F6);
const _socialIconColor = Color(0xFF99A1AF);

/// Matches the website's global footer (Terms of Use / Your Profile /
/// Support + LinkedIn) — shown at the bottom of every main screen.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final links = Wrap(
      alignment: WrapAlignment.center,
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
    );
    const linkedIn = _LinkedInBadge();

    // CSS ref: footer#footer — padding 20px 32px, border-top 1px
    // #E5E7EB, background #F4F5F7. Mobile breakpoint overrides to
    // padding: 20px var(--spacing-md) (16px) and stacks column-wise.
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 16,
        vertical: 20,
      ),
      decoration: const BoxDecoration(
        color: _footerBg,
        border: Border(top: BorderSide(color: _footerBorder)),
      ),
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
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovering) => InkWell(
        onTap: onTap,
        child: Text(
          label,
          // CSS ref: #footer .footer-menu ul li a — font-size 14px,
          // font-weight 500, color #6b7280; :hover — color #693D94.
          style: GoogleFonts.inter(
            color: hovering ? _footerTextHover : _footerText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// CSS ref: #footer .social-link ul li a — 36x36 circle, bg #f3f4f6 (the
// :hover rule sets the identical bg/color, i.e. no visible hover change).
// #footer .social-link ul li a i — color #99A1AF, font-size 18px.
class _LinkedInBadge extends StatelessWidget {
  const _LinkedInBadge();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(
        Uri.parse('https://www.linkedin.com/company/looking-forward-consulting'),
        mode: LaunchMode.externalApplication,
      ),
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: _socialBadgeBg,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          LucideIcons.linkedin,
          size: 18,
          color: _socialIconColor,
        ),
      ),
    );
  }
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:form_validator/form_validator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/gen/assets.gen.dart';
import 'package:lms/app/features/courses/view/content_viewer/in_app_webview_page.dart';
import 'package:url_launcher/url_launcher.dart';

import '../viewmodel/signin_viewmodel.dart';

// CSS ref: `backend/web/dist/app.css` (body.login / .form-wrap /
// .form-content / .form-control / .forgot-password) + the inline <style>
// block in `backend/views/sign-in/login.php` for the <=767px rules.
// NOTE: this theme's body font is Roboto (`body{font-family:"Roboto"}`),
// unlike the course pages' Outfit/Inter stack — every text style here is
// Roboto for that reason.
//
// body.login — bg #ECE9FF with login-bg.png pinned bottom/contain.
// .form-wrap — desktop 780px pushed right (the live card renders much
// wider than the checked-in 610px); 580px at <=1500px; <=991px centered;
// <=640px full width with 20px sides and stacked full-width buttons.
// .form-content — white card, padding 44/60 (24/30 <=1500px),
//   border 1px --primary-first, shadow 0 4px 26px rgba(0,0,0,.15),
//   radius 16; transparent (no chrome) on phones.
// h1 — 25px/400/#979797, margins 70/0/25, centered (phones: 34px/600,
//   margins 20/0/35).
// .form-control — border #BFC9D4, text #3B3F5C 15px, padding 8/10,
//   radius 6, envelope/lock prefix icons.
// Buttons — centered row of 107x40 Log in (radius 8, purple-darken
// hover) + plain purple "Sign up" text link with a lavender hover pill;
// stacked on phones.
// .forgot-password — centered, link 18px #979797 with NO underline.
// Deliberate deviations: both fields stay visible (the site reveals the
// password box only after a valid email via JS); the Privacy Policy link
// below is app-only (App Store requirement), not on the website.
const _loginPurple = Color(0xFF693D94);
const _loginBg = Color(0xFFECE9FF);
const _ink = Color(0xFF3B3F5C);
const _inputBorder = Color(0xFFBFC9D4);
const _muted = Color(0xFF979797);
const _errorPink = Color(0xFFE08A9E);
const _helpGrey = Color(0xFF999999);

const _signUpUrl =
    'https://staging.trainingpipeline.com/backend/web/sign-in/sign-up';
const _forgotPasswordUrl =
    'https://staging.trainingpipeline.com/backend/web/sign-in/request-password-reset';
const _supportEmail = 'support@trainingpipeline.com';

class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(SignInViewModel.provider);
    final width = MediaQuery.sizeOf(context).width;
    final phone = width < 768;
    final tablet = width >= 768 && width < 992;
    // Card 780px on wide desktop, 580px at <=1500px (both right-aligned);
    // centered on tablets; transparent full-width strip on phones.
    final cardWidth = width > 1500 ? 780.0 : 580.0;

    return Scaffold(
      backgroundColor: _loginBg,
      body: Stack(
        children: [
          // Failsafe: deep-purple gradient pinned to the very bottom,
          // strictly behind the scene. When the scene sits correctly its
          // opaque waves cover this zone entirely (zero visual change);
          // if any inset ever exposes pixels below the waves, purple —
          // never pale scaffold — shows instead. IgnorePointer keeps
          // footer links tappable wherever the form overlaps this zone.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 160,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.5, 1.0],
                    colors: [Colors.transparent, Color(0xFF5940B4)],
                  ),
                ),
              ),
            ),
          ),
          // body.login background — same treatment on all breakpoints
          // (web parity): full-width scene anchored to the bottom. The
          // source art is very wide (1440x495), so it renders as a compact
          // band with the lavender page bg above it, exactly like the site.
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Assets.images.loginBg.image(
                width: width,
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          SafeArea(
            child:
                phone
                    // <=640px: transparent wrapper, 20px sides.
                    ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: _LoginForm(
                        viewModel: viewModel,
                        phone: true,
                      ),
                    )
                    : tablet
                    // <=991px: card centered.
                    ? Center(
                      child: SingleChildScrollView(
                        child: _LoginCard(
                          width: cardWidth,
                          viewModel: viewModel,
                        ),
                      ),
                    )
                    // Desktop: card pushed right.
                    : Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.all(context.xLargeSpace),
                        child: SingleChildScrollView(
                          child: _LoginCard(
                            width: cardWidth,
                            viewModel: viewModel,
                          ),
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

/// The white `.form-content` card (desktop/tablet only).
class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.width, required this.viewModel});

  final double width;
  final dynamic viewModel;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 1500;
    return Container(
      width: width,
      // Taller card: 44px top/bottom padding on wide desktop, 24px at
      // <=1500px (horizontal stays 60/30).
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 60 : 30,
        vertical: wide ? 44 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _loginPurple),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 26,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: _LoginForm(viewModel: viewModel, phone: false),
    );
  }
}

class _LoginForm extends ConsumerWidget {
  const _LoginForm({required this.viewModel, required this.phone});

  final dynamic viewModel;
  final bool phone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Form(
      key: viewModel.formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: phone ? 20 : 70),
          // .form-wrap .form-content h1 — centered.
          Text(
            "login".translate(context),
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              color: _muted,
              fontSize: phone ? 34 : 25,
              fontWeight: phone ? FontWeight.w600 : FontWeight.w400,
              height: phone ? null : 1.0,
            ),
          ),
          SizedBox(height: phone ? 35 : 25),
          TextFormField(
            controller: viewModel.email,
            validator: ValidationBuilder().email().build(),
            textAlignVertical: TextAlignVertical.center,
            style: GoogleFonts.roboto(
              color: _ink,
              fontSize: 15,
              letterSpacing: 1,
            ),
            decoration: InputDecoration(
              hintText: "email".translate(context),
              prefixIcon: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 18, 0),
                child: SvgPicture.asset(
                  'assets/images/envelope.svg',
                  width: 32,
                  fit: BoxFit.contain,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _inputBorder),
              ),
              // .field-loginform-*.help-block — pink italic.
              errorStyle: GoogleFonts.roboto(
                color: _errorPink,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable:
                viewModel.isPasswordHidden as ValueNotifier<bool>,
            builder: (context, isHidden, _) {
              return TextFormField(
                controller: viewModel.password,
                validator: ValidationBuilder().minLength(5).build(),
                obscureText: isHidden,
                textAlignVertical: TextAlignVertical.center,
                style: GoogleFonts.roboto(
                  color: _ink,
                  fontSize: 15,
                  letterSpacing: 1,
                ),
                decoration: InputDecoration(
                  hintText: "password".translate(context),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 18, 0),
                    child: SvgPicture.asset(
                      'assets/images/lock.svg',
                      width: 26,
                      fit: BoxFit.contain,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      viewModel.isPasswordHidden.value = !isHidden;
                    },
                    icon: Icon(
                      isHidden
                          ? HugeIcons.strokeRoundedViewOffSlash
                          : HugeIcons.strokeRoundedView,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: _inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: _inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: _inputBorder),
                  ),
                  errorStyle: GoogleFonts.roboto(
                    color: _errorPink,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: viewModel.rememberMe,
                onChanged: viewModel.toggleRememberMe,
                // Live site: square box; checked fill is green.
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                side: const BorderSide(color: Color(0xFFADB5BD)),
                fillColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      states.contains(WidgetState.selected)
                          ? const Color(0xFF28A745)
                          : Colors.white,
                ),
                checkColor: Colors.white,
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap:
                      () => viewModel.toggleRememberMe(
                        !viewModel.rememberMe,
                      ),
                  child: Text(
                    "keep_me_logged_in".translate(context),
                    style: GoogleFonts.roboto(
                      color: const Color(0xFF6B7280),
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (phone) ...[
            _LoginButton(viewModel: viewModel, fullWidth: true),
            const SizedBox(height: 10),
            const Center(child: _SignUpButton()),
          ] else ...[
            // .form-buttons-group — centered row.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LoginButton(viewModel: viewModel),
                const SizedBox(width: 24),
                const _SignUpButton(),
              ],
            ),
          ],
          const SizedBox(height: 25),
          // .forgot-password — centered, 18px grey link, no underline.
          Center(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap:
                    () => InAppWebViewPage.show(
                      context,
                      url: _forgotPasswordUrl,
                      title: 'Forgot Password',
                    ),
                child: Text(
                  'Forgot Password',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    color: _muted,
                    fontSize: 18,
                    height: 25 / 18,
                  ),
                ),
              ),
            ),
          ),
          // "Need help? Contact us at ..." footer (mailto link shows a
          // pointer cursor like every other tappable text here).
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: 'Need help? Contact us at ',
                  style: GoogleFonts.roboto(
                    color: _helpGrey,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(
                      text: _supportEmail,
                      style: GoogleFonts.roboto(
                        color: _loginPurple,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      recognizer:
                          TapGestureRecognizer()
                            ..onTap =
                                () => launchUrl(
                                  Uri.parse('mailto:$_supportEmail'),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Privacy Policy link (required by App Store) ──
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap:
                  () => InAppWebViewPage.show(
                    context,
                    url: 'https://leadershipedge.live/privacy-policy',
                    title: 'Privacy Policy',
                  ),
              child: Text(
                'Privacy Policy',
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.appColorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: context.appColorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Log in button — 107x40 desktop/tablet, full-width on phones.
/// Hover darkens the purple (the live button reads as a purple-darken,
/// not the stale theme's blue `.btn-primary:hover`).
class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.viewModel, this.fullWidth = false});

  final dynamic viewModel;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: GoogleFonts.roboto(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      fixedSize: fullWidth ? null : const Size(107, 40),
      minimumSize: fullWidth ? const Size(double.infinity, 40) : const Size(107, 40),
    ).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.hovered)
                ? const Color(0xFF5A3480)
                : _loginPurple,
      ),
    );
    Widget button = AdminElevatedResponsiveButton(
      controller: viewModel.submitButtonController,
      buttonStyle: style,
      onPressed: () {
        viewModel
            .submit(context)
            .then(
              (value) {
                if (value == true) {
                  Modular.to.navigate(
                    CoursesModule.construct(CoursesModule.dashboard),
                  );
                }
              },
              onError: (error) {
                Toast.error(context, _loginErrorText(error));
              },
            );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Text("login".translate(context))],
      ),
    );
    if (fullWidth) {
      button = SizedBox(
        width: double.infinity,
        height: 40,
        child: button,
      );
    }
    return button;
  }
}

/// Sign up — plain purple text link that gains a soft lavender pill
/// behind it on hover.
class _SignUpButton extends StatelessWidget {
  const _SignUpButton();

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder:
          (context, hovering) => GestureDetector(
            onTap:
                () => InAppWebViewPage.show(
                  context,
                  url: _signUpUrl,
                  title: 'Sign up',
                ),
            // Instant (non-animated) swap: lerping transparent-black to
            // lavender would flash an intermediate grey, i.e. a second bg.
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color:
                    hovering
                        ? const Color(0xFFF5F3FF)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Sign up',
                style: GoogleFonts.roboto(
                  color: _loginPurple,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
    );
  }
}

/// The backend's own login-failure message says "Auth Key" (its internal
/// term for the credential it checks), but this screen only ever shows the
/// user a "Password" field — so that wording is rewritten before display.
String _loginErrorText(Object error) {
  return error.toString().replaceAll(
    RegExp(r'auth\s*key', caseSensitive: false),
    'Password',
  );
}

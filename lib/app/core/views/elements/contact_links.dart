import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/view/content_viewer/in_app_webview_page.dart';

/// Shared "Contact a Coach" links — opens inside the app via InAppWebViewPage
/// so the OAuth session carries over without switching to the system browser.
Future<void> launchContactCoachUrl(WidgetRef ref, BuildContext context) async {
  final user = ref.read(AuthStateNotifier.provider)?.user;
  final email = Uri.encodeComponent(user?.email ?? '');
  final authKey = Uri.encodeComponent(user?.authKey ?? '');
  final url =
      'https://login.leadershipedge.coach/backend/web/sign-in/oauth-login?email=$email&authkey=$authKey';
  if (!context.mounted) return;
  await InAppWebViewPage.show(context, url: url, title: 'Contact a Coach');
}

Future<void> launchVirtualDevUrl(BuildContext context) async {
  const url =
      'https://staging.trainingpipeline.com/backend/web/chatgpt/virtual-development-pro/index';
  if (!context.mounted) return;
  await InAppWebViewPage.show(context, url: url, title: 'Virtual Development Pro');
}

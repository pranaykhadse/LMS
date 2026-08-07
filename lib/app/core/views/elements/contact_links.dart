import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared "Contact a Coach" external links — used by both the mobile
/// drawer and the desktop nav bar.
Future<void> launchContactCoachUrl(WidgetRef ref) async {
  final user = ref.read(AuthStateNotifier.provider)?.user;
  final email = Uri.encodeComponent(user?.email ?? '');
  final authKey = Uri.encodeComponent(user?.authKey ?? '');
  final uri = Uri.parse(
    'https://login.leadershipedge.coach/backend/web/sign-in/oauth-login?email=$email&authkey=$authKey',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> launchVirtualDevUrl() async {
  final uri = Uri.parse(
    'https://staging.trainingpipeline.com/backend/web/chatgpt/virtual-development-pro/index',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

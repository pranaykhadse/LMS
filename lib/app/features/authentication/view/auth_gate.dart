import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app_module.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _checking = true;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  Future<void> _checkAuth() async {
    try {
      await ref.read(InternetConnectionProvider.provider).intialize();
    } catch (_) {
      // Connectivity check failure is non-fatal.
    }
    try {
      await ref.read(AuthStateNotifier.provider.notifier).initialize();
    } catch (_) {
      // Auth init failure is treated as logged-out.
    }

    if (!mounted) return;
    if (ref.read(AuthStateNotifier.provider) == null) {
      _goToLogin();
      return;
    }
    setState(() => _checking = false);
  }

  void _goToLogin() {
    if (_redirecting) return;
    _redirecting = true;
    Modular.to.navigate(AppModule.auth);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(AuthStateNotifier.provider);
    if (!_checking && auth == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goToLogin();
      });
    }

    if (_checking || auth == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return widget.child;
  }
}

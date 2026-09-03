import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/dashboard/viewmodel/user_points_view_model.dart';
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
    // Per explicit request: the "Redeem your Points" nav badge should
    // have real data as soon as the app opens (an existing session
    // restoring here) or right after a fresh login - not only once the
    // user happens to visit Redeem Points or Dashboard. `fetchIfNeeded`
    // is a no-op once a balance is already known or a fetch is already
    // in flight, so scheduling it on every build this widget makes while
    // logged in is cheap and covers both an app-open session restore and
    // a later fresh login (this same gate rebuilds either way, since it
    // watches `AuthStateNotifier` directly). Deferred a frame, same as
    // `_checkAuth`, rather than reading a provider notifier mid-build.
    if (auth != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(UserPointsViewModel.provider.notifier).fetchIfNeeded();
      });
    }
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

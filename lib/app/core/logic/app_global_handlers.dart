/// Bridges lower-level repo/error code to app-level actions (navigation,
/// auth state) without creating a hard dependency on the UI layer.
///
/// Set once during app startup (see [MyApp] in main.dart).
class AppGlobalHandlers {
  AppGlobalHandlers._();

  static void Function()? _onUnauthorized;
  static bool _isHandling = false;

  /// Register the callback that should run when any API call returns 401/403.
  static set onUnauthorized(void Function() cb) => _onUnauthorized = cb;

  /// Called from [handelException] in error.dart when a 401/403 is received.
  /// Debounced so rapid successive 401s only trigger one logout/navigation.
  static void handleUnauthorized() {
    if (_isHandling || _onUnauthorized == null) return;
    _isHandling = true;
    _onUnauthorized!();
    // Reset after a short delay in case the user logs back in quickly.
    Future.delayed(const Duration(seconds: 3), () => _isHandling = false);
  }
}

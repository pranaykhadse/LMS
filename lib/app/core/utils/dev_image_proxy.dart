import 'package:flutter/foundation.dart';

/// Routes [url] through the local dev_cors_proxy.js (see run_chrome_dev.bat)
/// so images from hosts other than the API's own origin (e.g.
/// test.login.trainingpipeline.com course logos) don't fail to load with a
/// CORS error in a normal Chrome window during local `flutter run -d chrome`
/// testing.
///
/// Only active for debug web builds - inert (returns [url] unchanged) in
/// profile/release builds and on every other platform, so this never
/// affects real users; it only exists to make local dev/testing match what
/// production actually renders once CORS isn't a factor (native builds,
/// or the real deployed web app served from the same origin as its images).
String devProxiedImageUrl(String url) {
  if (!kDebugMode || !kIsWeb) return url;
  return 'http://localhost:8081/img?url=${Uri.encodeComponent(url)}';
}

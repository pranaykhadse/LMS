import 'package:flutter/cupertino.dart';
// import 'package:lms/gen/assets.gen.dart';

class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 100});

  /// Target height — width scales automatically to preserve the source
  /// image's own aspect ratio instead of being squashed into a square.
  final double size;

  @override
  Widget build(BuildContext context) {
    // return FlutterLogo(size: size);
    return Image.asset(
      "assets/images/logo.png",
      height: size,
      fit: BoxFit.contain,
    );
  }
}

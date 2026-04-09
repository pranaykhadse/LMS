import 'package:flutter/cupertino.dart';
// import 'package:lms/gen/assets.gen.dart';

class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 100});
  final double size;
  @override
  Widget build(BuildContext context) {
    // return FlutterLogo(size: size);
    return Image.asset("assets/images/logo.png", height: size, width: size);
  }
}

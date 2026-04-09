import 'package:flutter/material.dart';
import 'package:lms/app/core/utils/utils.dart';

class PrimaryCard extends StatelessWidget {
  const PrimaryCard({
    super.key,
    required this.child,
    this.padding,
    this.constraints,
    this.radius,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets? padding;
  final BoxConstraints? constraints;
  final double? radius;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: padding,
        constraints: constraints,
        decoration: BoxDecoration(
          color: context.appColorScheme.primaryCard,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(50),
              // blurRadius: 0,
              // spreadRadius: 1,
            )
          ],
          borderRadius: BorderRadius.circular(
            radius ?? context.smallRadius,
          ),
        ),
        child: child,
      ),
    );
  }
}

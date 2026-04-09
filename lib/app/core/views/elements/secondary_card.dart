import 'package:flutter/material.dart';
import 'package:lms/app/core/utils/utils.dart';

class SecondaryCard extends StatelessWidget {
  const SecondaryCard({
    super.key,
    required this.child,
    this.padding,
    this.constraints,
    this.color,
    this.radius,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets? padding;
  final BoxConstraints? constraints;
  final Color? color;
  final double? radius;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        padding: padding ?? EdgeInsets.all(context.smallSpace),
        constraints: constraints,
        decoration: BoxDecoration(
          color: color ?? context.appColorScheme.primaryCard,
          border: Border.all(
            color: context.appColorScheme.primary.withAlpha(75),
          ),
          borderRadius: BorderRadius.circular(radius ?? context.smallRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 5,
              offset: Offset(2.5, 2.5),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

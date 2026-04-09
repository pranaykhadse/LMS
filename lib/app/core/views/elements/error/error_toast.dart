import 'package:flutter/material.dart';
import 'package:lms/app/core/utils/size_utils.dart';
import 'package:lms/app/core/utils/theme_utils.dart';

class ErrorToastWidget extends StatefulWidget {
  const ErrorToastWidget({
    super.key,
    required this.duration,
    this.error,
    required this.title,
  });
  final dynamic error;
  final String title;
  final Duration duration;
  @override
  State<ErrorToastWidget> createState() => _ErrorToastWidgetState();
}

class _ErrorToastWidgetState extends State<ErrorToastWidget>
    with SingleTickerProviderStateMixin {
  late final animationControler = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  @override
  void initState() {
    super.initState();
    animationControler.forward(from: 0);
  }

  @override
  void dispose() {
    animationControler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.smallSpace),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: context.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(context.mediumRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.all(context.minorSpace),
                padding: EdgeInsets.only(
                  left: context.minorSpace / 2,
                  right: context.minorSpace / 2,
                  bottom: context.minorSpace / 2,
                ),
                decoration: BoxDecoration(
                  color: context.appColorScheme.error.withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(context.minorSpace / 2),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: context.appColorScheme.error,
                    size: context.mediumSize,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(context.minorSpace),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: context.minorSpace / 2,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: context.minorSpace / 2,
                        ),
                        child: Text(
                          widget.title,
                          style: context.textTheme.labelLarge,
                        ),
                      ),
                      Text(
                        widget.error.toString(),
                        // style: context.textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          AnimatedBuilder(
            animation: animationControler,
            builder: (context, _) {
              return LinearProgressIndicator(
                value: 1 - animationControler.value,
                color: context.appColorScheme.error,
                backgroundColor: Colors.transparent,
              );
            },
          ),
        ],
      ),
    );
  }
}

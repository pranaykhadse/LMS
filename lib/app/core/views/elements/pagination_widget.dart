import 'package:flutter/material.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/model/page_info.dart';

class PaginationWidget extends StatelessWidget {
  const PaginationWidget({
    super.key,
    required this.pageInfo,
    required this.onPageChange,
  });
  final PageInfo pageInfo;
  final ValueChanged<int> onPageChange;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.smallSpace),
      child: Row(
        spacing: context.smallSpace,
        children: List.generate(pageInfo.pages ?? 1, (index) {
          var i = (index + 1);
          final color =
              i == pageInfo.page ? context.colorScheme.primary : Colors.grey;
          return InkWell(
            onTap: () {
              if (i != pageInfo.page) {
                onPageChange(i);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.minorRadius),
                border: Border.all(color: color),
              ),
              padding: EdgeInsets.all(context.minorSpace),
              child: Text(
                i.toString(),
                style: context.textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
          );
        }),
      ),
    );
  }
}

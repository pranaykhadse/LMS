import 'package:flutter/material.dart';
import 'package:lms/app/core/localization/translate.dart';
import 'package:lms/app/core/utils/theme_utils.dart';

class TableActionButton extends StatelessWidget {
  const TableActionButton({super.key, this.onEdit, this.onDelete});
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: Icon(
        Icons.more_vert_outlined,
        color: context.appColorScheme.textColor,
      ),
      tooltip: "Click to View actions",
      itemBuilder: (context) {
        return [
          if (onEdit != null)
            PopupMenuItem(
              onTap: onEdit,
              child: Text("Edit".translate(context)),
            ),
          if (onDelete != null)
            PopupMenuItem(
              onTap: onDelete,
              child: Text("Delete".translate(context)),
            ),
        ];
      },
    );
  }
}

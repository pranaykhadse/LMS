import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/views/elements/connection_aware_widget.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';

class FlatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const FlatAppBar({
    super.key,
    required this.title,
    this.actions,
    this.enableBack = true,
  });
  final String title;
  final List<Widget>? actions;
  final bool enableBack;

  @override
  Widget build(BuildContext context, ref) {
    var userProfile2 = ref.watch(AuthStateNotifier.provider)?.userProfile;
    return PrimaryCard(
      // color: context.appColorScheme.background,
      // centerTitle: true,
      child: Row(
        children: [
          Opacity(
            opacity: enableBack ? 1.0 : 0.0,
            child: AbsorbPointer(
              absorbing: !enableBack,
              child: IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: Icon(HugeIcons.strokeRoundedArrowLeft01),
              ),
            ),
          ),
          SizedBox(width: context.smallSpace),

          Text("Course Catalog", style: context.textTheme.titleLarge),
          SizedBox(width: context.smallSpace),
          ConnectionAwareWidget(
            offlineChild: Chip(
              label: Text(
                "OFFLINE",
                style: context.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.redAccent,
            ),
            onlineChild: SizedBox(),
          ),
          Spacer(),
          SizedBox(width: context.minorSpace),

          PopupMenuButton(
            itemBuilder: (context) {
              return [
                PopupMenuItem(
                  onTap: () {
                    ref.read(AuthStateNotifier.provider.notifier).logout();
                    Modular.to.navigate("/");
                  },
                  child: Row(
                    spacing: context.minorSpace,
                    children: [Icon(Icons.logout), Text("Logout")],
                  ),
                ),
              ];
            },
            child: Row(
              children: [
                CircleAvatar(child: Icon(Icons.person)),
                SizedBox(width: context.minorSpace),
                Center(
                  child: Text(
                    "${userProfile2?.firstname ?? ""} ${(userProfile2?.middlename ?? "")} ${userProfile2?.lastname ?? ""}",
                    style: context.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.minorSpace),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => AppBar().preferredSize;
}

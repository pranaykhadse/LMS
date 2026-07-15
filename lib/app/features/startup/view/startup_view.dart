import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';

import '../view_model/startup_view_model.dart';

class StartupView extends ConsumerWidget {
  const StartupView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _ = ref.watch(StartupViewModel.provider);

    return Scaffold(
      body: Center(child: Logo(size: context.screenSize.shortestSide * 0.5)),
    );
  }
}

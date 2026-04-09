import 'package:flutter/material.dart';

import '../../logic/data_state/data_state.dart';

Widget _defaultLoader(_) {
  return const Center(
    child: CircularProgressIndicator(),
  );
}

Widget _defaultErrorBuilder(context, dynamic error) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.warning_rounded,
          color: Theme.of(context).colorScheme.error.withOpacity(0.75),
          size: 100,
        ),
        Text("$error"),
      ],
    ),
  );
}

class DataStateBuilder<T> extends StatelessWidget {
  const DataStateBuilder({
    super.key,
    required this.dataState,
    this.loader = _defaultLoader,
    this.idleBuilder,
    this.error = _defaultErrorBuilder,
    required this.builder,
  });
  final Widget Function(BuildContext context) loader;
  final Widget Function(BuildContext context)? idleBuilder;
  final Widget Function(BuildContext context, dynamic error) error;
  final Widget Function(BuildContext context, T? data) builder;
  final DataState<T> dataState;

  @override
  Widget build(BuildContext context) {
    switch (dataState.state) {
      case DataProviderState.data:
        return builder.call(context, dataState.data);

      case DataProviderState.error:
        return error.call(context, dataState.error);

      case DataProviderState.idle:
        return idleBuilder?.call(context) ?? loader.call(context);
      // case DataProviderState.loading:
      default:
        return loader.call(
          context,
        );
    }
  }
}

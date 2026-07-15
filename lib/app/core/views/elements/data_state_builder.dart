import 'package:flutter/material.dart';

import '../../logic/data_state/data_state.dart';
import '../../logic/repository/app_exception.dart';

Widget _defaultLoader(_) {
  return const Center(
    child: CircularProgressIndicator(),
  );
}

Widget _defaultErrorBuilder(BuildContext context, dynamic error) {
  // Show a friendly message for token expiry / auth errors instead of
  // the raw "Unauthorized: Your request was made with invalid credentials."
  final isUnauthorized = error is UnauthorizedException ||
      error.toString().toLowerCase().startsWith('unauthorized');

  final message = isUnauthorized
      ? 'Your session has expired.\nPlease log out and sign in again.'
      : '$error';

  final icon = isUnauthorized
      ? Icons.lock_outline_rounded
      : Icons.warning_rounded;

  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.error.withOpacity(0.75),
            size: 72,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
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

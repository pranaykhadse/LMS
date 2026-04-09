import 'package:flutter/cupertino.dart';

typedef ValidatorFunction<T> = String? Function(T? value);

abstract class VimsInputFieldController<T> {
  T? get value => valueNotifier.value;

  void setInitialValue(T? value);

  final List<ValidatorFunction<T>> validators;

  final String? label;

  final valueNotifier = ValueNotifier<T?>(null);
  final ValueNotifier<bool> _enabledSubject = ValueNotifier<bool>(true);

  bool get enabled => _enabledSubject.value;

  set enabled(bool value) {
    _enabledSubject.value = value;
  }

  final FocusNode focusNode = FocusNode();

  void onChange(T? value) {
    valueNotifier.value = value;
  }

  VimsInputFieldController({
    this.validators = const [],
    this.label,
  });

  String? validate(T? value) {
    for (var validator in validators) {
      String? error = validator.call(value);
      if (error != null) return error;
    }
    return null;
  }
}

enum LabelPosition {
  top,
  inside,
  none,
}
///
/// function to get beautified String for label position
/// 
///

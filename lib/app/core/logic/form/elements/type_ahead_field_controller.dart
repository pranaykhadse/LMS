// import 'package:flutter/cupertino.dart';
// import 'package:flutter_typeahead/flutter_typeahead.dart';

// import 'input_field_controller.dart';

// class VimsTypeAheadFieldController<T> extends VimsInputFieldController<T> {
//   late TextEditingController textEditingController;
//   final TextInputType inputType;
//   final int maxLines;
//   final String? hintText;

//   final Future<List<T>> Function(String) suggestionCallback;
//   final String Function(T) displayCallback;
//   VimsTypeAheadFieldController({
//     String? text,
//     super.label,
//     this.hintText,
//     this.inputType = TextInputType.text,
//     this.maxLines = 1,
//     super.validators = const [],
//     required this.suggestionCallback,
//     required this.displayCallback,
//     bool autoClearOnFocusChange = true,
//   }) : super() {
//     textEditingController = TextEditingController(text: text);
//     focusNode.addListener(() {
//       suggestionsController.refresh();
//       if (autoClearOnFocusChange) {
//         textEditingController.text =
//             value == null ? "" : displayCallback(value as T);
//       }
//     });
//   }

//   @override
//   void setInitialValue(T? value) {
//     onChange(value);
//   }

//   final suggestionsController = SuggestionsController<T>();

//   @override
//   void onChange(T? value) {
//     super.onChange(value);
//     textEditingController.text = value != null ? displayCallback(value) : "";
//     focusNode.unfocus();
//   }

//   TextInputType get keyboardType => inputType;
// }

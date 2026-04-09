// import 'package:flutter/material.dart';
// import 'package:linked_scroll_controller/linked_scroll_controller.dart';
// import 'package:lms/app/core/logic/data_state/listing_page_state.dart';
// import 'package:lms/app/core/utils/size_utils.dart';
// import 'package:lms/app/core/utils/theme_utils.dart';
// import 'package:lms/app/core/views/elements/data_state_builder.dart';
// import 'package:lms/app/core/views/elements/primary_card.dart';

// class TableHeadder {
//   final int flex;
//   final String label;
//   final Alignment alignment;

//   TableHeadder({
//     this.flex = 1,
//     this.alignment = Alignment.center,
//     required this.label,
//   });
// }

// class VimsDataTable<T> extends StatefulWidget {
//   const VimsDataTable({
//     super.key,
//     required this.headder,
//     required this.state,
//     required this.rowBuilder,
//     required this.toggleSelection,
//     this.appliedFilters,
//     this.actionBuilder,
//   });
//   final List<TableHeadder> headder;
//   final ListingPageState<T> state;
//   final List<Widget> Function(BuildContext context, T data) rowBuilder;
//   final Widget Function(BuildContext context, T data)? actionBuilder;
//   final void Function(T data) toggleSelection;
//   final Widget? appliedFilters;

//   @override
//   State<VimsDataTable<T>> createState() => _VimsDataTableState<T>();
// }

// class _VimsDataTableState<T> extends State<VimsDataTable<T>> {
//   final linkedScrollController = LinkedScrollControllerGroup();
//   Map<String, ScrollController> controllers = {};

//   ScrollController getScrollForIndex(int index) {
//     if (controllers.containsKey(index.toString())) {
//       return controllers[index.toString()]!;
//     }
//     final controller = linkedScrollController.addAndGet();
//     controllers[index.toString()] = controller;
//     return controller;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         final totalFlex =
//             widget.headder.map((e) => e.flex).reduce((a, b) => a + b);
//         final widthPerFlex = ((constraints.maxWidth - 100.0 - 50) / totalFlex)
//             .clamp(100.0, 300.0);

//         final totalWidth = (totalFlex * widthPerFlex);
//         final hasActions = widget.actionBuilder != null;

//         return PrimaryCard(
//           child: SizedBox(
//             height: constraints.maxHeight,
//             child: Column(
//               children: [
//                 Container(
//                   margin: const EdgeInsets.all(5),
//                   constraints: const BoxConstraints(
//                     minHeight: 60,
//                   ),
//                   decoration: BoxDecoration(
//                     color: context.appColorScheme.secondaryCard,
//                     borderRadius: BorderRadius.vertical(
//                       top: Radius.circular(
//                         context.smallRadius,
//                       ),
//                     ),
//                   ),
//                   child: Row(
//                     children: [
//                       SizedBox(
//                         width: 50,
//                         child: Center(
//                           child: Checkbox(
//                             tristate: true,
//                             value: widget.state.selection.isEmpty
//                                 ? false
//                                 : widget.state.selection.length ==
//                                         widget.state.dataState.data?.length
//                                     ? true
//                                     : null,
//                             onChanged: (value) {
//                               if (widget.state.selection.isEmpty ||
//                                   widget.state.selection.length ==
//                                       widget.state.dataState.data?.length) {
//                                 for (var element
//                                     in widget.state.dataState.data ?? []) {
//                                   widget.toggleSelection.call(element);
//                                 }
//                               } else {
//                                 for (var element
//                                     in widget.state.dataState.data ?? []) {
//                                   if (widget.state.selection
//                                       .contains(element)) {
//                                     continue;
//                                   }
//                                   widget.toggleSelection.call(element);
//                                 }
//                               }
//                             },
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         child: SingleChildScrollView(
//                           scrollDirection: Axis.horizontal,
//                           controller: getScrollForIndex(-1),
//                           child: SizedBox(
//                             width: totalWidth,
//                             child: Row(
//                               children: [
//                                 for (var head in widget.headder)
//                                   Expanded(
//                                     flex: head.flex,
//                                     child: Align(
//                                       alignment: head.alignment,
//                                       child: Text(
//                                         head.label,
//                                         style: context.textTheme.labelLarge
//                                             ?.copyWith(
//                                           color: Colors.grey,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                       if (hasActions)
//                         SizedBox(
//                           width: 100,
//                           child: Center(
//                             child: Text(
//                               "Actions",
//                               style: context.textTheme.labelLarge?.copyWith(
//                                 color: Colors.grey,
//                               ),
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//                 Container(
//                   child: widget.appliedFilters,
//                 ),
//                 Expanded(
//                   child: DataStateBuilder(
//                     dataState: widget.state.dataState,
//                     builder: (context, data) {
//                       if (data == null || data.isEmpty) {
//                         return const Center(
//                           child: Text("No Data available."),
//                         );
//                       }

//                       return ListView.separated(
//                         separatorBuilder: (context, index) => Container(
//                           height: 1,
//                           width: double.infinity,
//                           color: context.appColorScheme.border,
//                         ),
//                         itemCount: data.length,
//                         itemBuilder: (context, index) {
//                           final children =
//                               widget.rowBuilder(context, data[index]);
//                           return SizedBox(
//                             height: 50,
//                             child: Row(
//                               children: [
//                                 Padding(
//                                   padding: const EdgeInsets.only(left: 5.0),
//                                   child: SizedBox(
//                                     width: 50,
//                                     child: Center(
//                                       child: Checkbox(
//                                         value: widget.state.selection
//                                             .contains(data[index]),
//                                         onChanged: (value) {
//                                           widget.toggleSelection(data[index]);
//                                         },
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 Expanded(
//                                     child: SingleChildScrollView(
//                                   scrollDirection: Axis.horizontal,
//                                   controller: getScrollForIndex(index),
//                                   child: SizedBox(
//                                     width: totalWidth,
//                                     height: 50,
//                                     child: Row(
//                                       children: [
//                                         for (int i = 0;
//                                             i < widget.headder.length;
//                                             i++)
//                                           Expanded(
//                                             flex: widget.headder[i].flex,
//                                             child: Container(
//                                               decoration: BoxDecoration(
//                                                   border: Border(
//                                                       right: BorderSide(
//                                                 color: context
//                                                     .appColorScheme.border,
//                                               ))),
//                                               child: Align(
//                                                 alignment:
//                                                     widget.headder[i].alignment,
//                                                 child: children[i],
//                                               ),
//                                             ),
//                                           ),
//                                       ],
//                                     ),
//                                   ),
//                                 )),
//                                 if (hasActions)
//                                   SizedBox(
//                                     width: 100,
//                                     height: 50,
//                                     child: Container(
//                                       decoration: BoxDecoration(
//                                           border: Border(
//                                               left: BorderSide(
//                                         color: context.appColorScheme.border,
//                                       ))),
//                                       child: widget.actionBuilder
//                                           ?.call(context, data[index]),
//                                     ),
//                                   ),
//                               ],
//                             ),
//                           );
//                         },
//                       );
//                     },
//                   ),
//                 )
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

import 'package:flutter/material.dart';

/// A pair of ScrollControllers whose offsets stay mirrored - for a table
/// whose header row is pinned in its own sliver (see StickyHeaderDelegate)
/// separately from its body rows, but both need to pan horizontally
/// together as one table. A single ScrollController can't be attached to
/// two Scrollables at once, so this listens on each and mirrors the offset
/// onto the other, guarding against the feedback loop that would otherwise
/// cause (each jumpTo triggering the other's listener right back).
class LinkedScrollControllers {
  LinkedScrollControllers() {
    header.addListener(() => _sync(header, body));
    body.addListener(() => _sync(header, body, reverse: true));
  }

  final ScrollController header = ScrollController();
  final ScrollController body = ScrollController();
  bool _syncing = false;

  void _sync(ScrollController header, ScrollController body, {bool reverse = false}) {
    if (_syncing) return;
    final from = reverse ? body : header;
    final to = reverse ? header : body;
    if (!to.hasClients || !from.hasClients) return;
    final target = from.offset.clamp(0.0, to.position.maxScrollExtent);
    if (to.offset == target) return;
    _syncing = true;
    to.jumpTo(target);
    _syncing = false;
  }

  void dispose() {
    header.dispose();
    body.dispose();
  }
}

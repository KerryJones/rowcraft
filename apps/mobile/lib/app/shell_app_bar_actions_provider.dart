import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Extra action widgets that individual screens inject into the shared
/// AppBar (e.g., sort button when browsing).
class ShellAppBarActionsNotifier extends Notifier<List<Widget>> {
  @override
  List<Widget> build() => const [];

  void set(List<Widget> actions) => state = actions;
}

final shellAppBarActionsProvider =
    NotifierProvider<ShellAppBarActionsNotifier, List<Widget>>(
        ShellAppBarActionsNotifier.new);

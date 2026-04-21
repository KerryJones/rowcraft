import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Provider that individual screens can override to inject extra action
/// widgets into the shared AppBar (e.g., sort button when browsing).
final shellAppBarActionsProvider = StateProvider<List<Widget>>((ref) => []);

import 'package:flutter/widgets.dart';

/// M3 window size classes based on width.
enum WindowSizeClass { compact, medium, expanded }

/// - compact: 0–599dp (phones)
/// - medium: 600–839dp (tablet portrait, 7" landscape)
/// - expanded: 840+dp (10" tablet landscape)
WindowSizeClass windowSizeClass(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 600) return WindowSizeClass.compact;
  if (width < 840) return WindowSizeClass.medium;
  return WindowSizeClass.expanded;
}

bool isTablet(BuildContext context) =>
    windowSizeClass(context) != WindowSizeClass.compact;

double contentMaxWidth(BuildContext context) =>
    isTablet(context) ? 640 : double.infinity;

EdgeInsets adaptivePadding(BuildContext context) => EdgeInsets.symmetric(
      horizontal: isTablet(context) ? 24 : 16,
    );

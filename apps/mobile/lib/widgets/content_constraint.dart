import 'package:flutter/widgets.dart';

import '../app/adaptive.dart';

/// Centers and constrains child width on tablet. No-op on phones.
class ContentConstraint extends StatelessWidget {
  final double? maxWidth;
  final Widget child;

  const ContentConstraint({super.key, this.maxWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    final effectiveMax = maxWidth ?? contentMaxWidth(context);
    if (effectiveMax == double.infinity) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMax),
        child: child,
      ),
    );
  }
}

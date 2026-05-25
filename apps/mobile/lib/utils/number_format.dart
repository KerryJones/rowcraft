import 'package:intl/intl.dart';

// Pinned to en_US so the separator is always a comma — app text is English
// and tests compare against literal "1,000" formatting.
final _decimalFormat = NumberFormat.decimalPattern('en_US');

String formatThousands(num n) => _decimalFormat.format(n);

String formatThousandsIfLarge(num n) =>
    n.abs() >= 1000 ? formatThousands(n) : n.toString();

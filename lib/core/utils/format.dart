import 'package:intl/intl.dart';

final _peso = NumberFormat.currency(locale: 'fil_PH', symbol: '₱');
String formatPeso(double amount) => _peso.format(amount);

String formatDate(DateTime dt) => DateFormat('MMM d, y hh:mm a').format(dt);

/// Capitalizes the first letter of each word in a string.
String capitalize(String? text) {
  if (text == null || text.trim().isEmpty) return '';
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

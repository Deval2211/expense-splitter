import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for the user's preferred currency symbol.
const String currencySymbolPrefKey = 'currencySymbol';

/// Default currency symbol used across the app.
const String defaultCurrencySymbol = '₹';

/// Common currency symbols available for user selection.
const List<String> supportedCurrencySymbols = [
  '₹', // Indian Rupee
  '\$', // US Dollar / Canadian Dollar / Australian Dollar
  '€', // Euro
  '£', // British Pound
  '¥', // Japanese Yen / Chinese Yuan
  '₩', // South Korean Won
  '฿', // Thai Baht
  'CHF', // Swiss Franc
];

/// Currently selected currency symbol. Loaded from SharedPreferences at
/// startup via [getCurrencySymbol] and updated by [setCurrencySymbol].
String _currentSymbol = defaultCurrencySymbol;

/// The user's preferred currency symbol (defaults to '₹').
String get currencySymbol => _currentSymbol;

/// Formats a numeric amount with a currency symbol and 2 decimal places.
///
/// Uses the user's preferred symbol unless [symbol] is provided.
///
/// Example:
/// ```dart
/// formatCurrency(150.0); // '₹150.00'
/// formatCurrency(49.9, symbol: '\$'); // '\$49.90'
/// ```
String formatCurrency(double amount, {String? symbol}) {
  return '${symbol ?? _currentSymbol}${amount.toStringAsFixed(2)}';
}

/// Reads the user's preferred currency symbol from SharedPreferences and
/// refreshes the cached symbol. Defaults to '₹' if not set.
Future<String> getCurrencySymbol() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    _currentSymbol = prefs.getString(currencySymbolPrefKey) ?? defaultCurrencySymbol;
  } catch (_) {
    _currentSymbol = defaultCurrencySymbol;
  }
  return _currentSymbol;
}

/// Saves the user's preferred currency symbol into SharedPreferences and
/// updates the cached symbol.
Future<void> setCurrencySymbol(String symbol) async {
  _currentSymbol = symbol;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(currencySymbolPrefKey, symbol);
}

import 'package:intl/intl.dart';

final NumberFormat _priceFormatter = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '',
  decimalDigits: 2,
);
final NumberFormat _integerFormatter = NumberFormat.decimalPattern('en_IN');

String formatPrice(num value) {
  return '₹${_priceFormatter.format(value)}';
}

/// Formats a JSON/API money field without turning unknown values into ₹0.00.
///
/// Only [formatPrice] is used after a finite number is parsed. Null, missing,
/// blank, non-numeric, NaN, and Infinity become `Unavailable`. A real `0` or
/// `"0.00"` stays `₹0.00`. Both reconciliation total and category rows share
/// this helper; do not use it where a typed `num` is already guaranteed.
String formatPriceValue(dynamic value) {
  final parsed = parseFinitePrice(value);
  if (parsed == null) return 'Unavailable';
  return formatPrice(parsed);
}

/// Returns a finite number, including `0`. Null means the value is unknown.
num? parseFinitePrice(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    if (value.isNaN || value.isInfinite) return null;
    return value;
  }
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final parsed = num.tryParse(text);
  if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
  return parsed;
}

String formatSignedPrice(num value) {
  final sign = value >= 0 ? '+' : '-';
  return '$sign₹${_priceFormatter.format(value.abs())}';
}

String formatIndex(num value) {
  return _priceFormatter.format(value);
}

String formatNumber(num value) {
  return _integerFormatter.format(value);
}

/// Unified client date-time for funds and product records.
String formatAppDateTime(DateTime? value) {
  if (value == null) return 'Unavailable';
  if (value.millisecondsSinceEpoch <= 0) return 'Unavailable';
  return DateFormat('dd MMM yyyy, HH:mm').format(value.toLocal());
}

DateTime toIst(DateTime value) =>
    value.toUtc().add(const Duration(hours: 5, minutes: 30));

/// Market quote / order clock in IST. Distinct from [formatAppDateTime] local time.
String formatIstDateTime(DateTime value) {
  final ist = toIst(value);
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(ist.day)}/${two(ist.month)}/${ist.year} '
      '${two(ist.hour)}:${two(ist.minute)} IST';
}

String formatVolume(num volume) {
  if (volume >= 10000000) {
    return '${(volume / 10000000).toStringAsFixed(2)} Cr';
  }

  if (volume >= 100000) {
    return '${(volume / 100000).toStringAsFixed(2)} L';
  }

  if (volume >= 1000) {
    return '${(volume / 1000).toStringAsFixed(1)} K';
  }

  return formatNumber(volume);
}

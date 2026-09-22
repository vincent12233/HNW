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

String formatPriceValue(dynamic value) {
  return formatPrice(num.tryParse(value?.toString() ?? '') ?? 0);
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

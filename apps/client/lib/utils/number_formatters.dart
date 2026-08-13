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

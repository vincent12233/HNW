import 'package:intl/intl.dart';

final NumberFormat _priceFormatter = NumberFormat('#,##0.00');
final NumberFormat _integerFormatter = NumberFormat('#,##0');

String formatPrice(num value) {
  return '₹${_priceFormatter.format(value)}';
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

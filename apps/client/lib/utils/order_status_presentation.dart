import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_chip.dart';

/// Display helpers for trading order status wire values.
/// Does not change backend enums or order semantics.
abstract final class OrderStatusPresentation {
  static String label(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pending';
      case 'OPEN':
        return 'Open';
      case 'PARTIALLY_FILLED':
        return 'Partially Filled';
      case 'FILLED':
        return 'Filled';
      case 'CANCELLED':
        return 'Cancelled';
      case 'REJECTED':
        return 'Rejected';
      case 'FAILED':
        return 'Failed';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  static AppChipVariant chipVariant(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return AppChipVariant.pending;
      case 'OPEN':
        return AppChipVariant.info;
      case 'PARTIALLY_FILLED':
        return AppChipVariant.info;
      case 'FILLED':
        return AppChipVariant.success;
      case 'CANCELLED':
        return AppChipVariant.neutral;
      case 'REJECTED':
      case 'FAILED':
        return AppChipVariant.failed;
      default:
        return AppChipVariant.neutral;
    }
  }

  static Color sideColor(String side) {
    final normalized = side.toUpperCase();
    if (normalized == 'BUY') return AppColors.buy;
    if (normalized == 'SELL') return AppColors.sell;
    return AppColors.textSecondary;
  }

  static String sideLabel(String side) {
    final normalized = side.toUpperCase();
    if (normalized == 'BUY') return 'BUY';
    if (normalized == 'SELL') return 'SELL';
    return side;
  }
}

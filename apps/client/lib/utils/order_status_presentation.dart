import 'package:flutter/material.dart';

import '../models/trading_order.dart';
import '../theme/app_colors.dart';
import '../utils/number_formatters.dart';
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

  static String typeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'LIMIT':
        return 'Limit';
      case 'MARKET':
        return 'Market';
      default:
        return type;
    }
  }

  static String tifLabel(String timeInForce) {
    switch (timeInForce.toUpperCase()) {
      case 'DAY':
        return 'DAY';
      case 'IOC':
        return 'IOC';
      case 'FOK':
        return 'FOK';
      default:
        return timeInForce;
    }
  }

  static IconData statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Icons.schedule_rounded;
      case 'OPEN':
        return Icons.hourglass_empty_rounded;
      case 'PARTIALLY_FILLED':
        return Icons.pie_chart_outline_rounded;
      case 'FILLED':
        return Icons.check_circle_outline_rounded;
      case 'CANCELLED':
        return Icons.cancel_outlined;
      case 'REJECTED':
      case 'FAILED':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  static bool canCancel(TradingOrder order) => order.isActive;

  static String maskReference(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '--';
    if (raw.length <= 12) return raw;
    return '${raw.substring(0, 4)}…${raw.substring(raw.length - 4)}';
  }

  static String formatIst(DateTime value) => formatIstDateTime(value);

  static String missing(String? value) {
    final raw = value?.trim() ?? '';
    return raw.isEmpty ? '--' : raw;
  }
}

Future<bool> confirmCancelTradingOrder(
  BuildContext context, {
  required TradingOrder order,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          '${OrderStatusPresentation.sideLabel(order.isBuy ? 'BUY' : 'SELL')} '
          '${order.symbol} · ${order.exchange}\n'
          'Remaining ${order.remainingQuantity} of ${order.quantity}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
            child: const Text('Confirm cancel'),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

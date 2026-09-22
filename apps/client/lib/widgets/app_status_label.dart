import 'package:flutter/material.dart';

import 'app_chip.dart';

AppChipVariant chipVariantForStatus(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'PENDING':
    case 'PROCESSING':
    case 'APPLIED':
    case 'UPCOMING':
      return AppChipVariant.pending;
    case 'APPROVED':
    case 'COMPLETED':
    case 'DISBURSED':
    case 'REPAID':
    case 'OPEN':
    case 'ACTIVE':
    case 'PUBLISHED':
      return AppChipVariant.success;
    case 'REJECTED':
    case 'NOT_ALLOTTED':
    case 'NOTALLOTTED':
    case 'CLOSED':
      return AppChipVariant.failed;
    case 'CANCELLED':
    case 'CANCELED':
      return AppChipVariant.neutral;
    case 'PARTIAL_REPAID':
    case 'OVERDUE':
    case 'ALLOCATED':
      return AppChipVariant.info;
    default:
      return AppChipVariant.neutral;
  }
}

String displayStatusLabel(
  String? raw, {
  Map<String, String> labels = const {},
}) {
  final key = (raw ?? '').trim().toUpperCase();
  if (key.isEmpty) return 'Unavailable';
  if (labels.containsKey(key)) return labels[key]!;
  if (RegExp(r'^[A-Z0-9_]+$').hasMatch(key) && !labels.containsKey(key)) {
    // Known financial enums we don't map stay readable; unknown stay honest.
    if (key.contains('_') ||
        const {
          'PENDING',
          'APPROVED',
          'REJECTED',
          'PROCESSING',
          'COMPLETED',
          'DISBURSED',
          'REPAID',
          'OPEN',
          'CLOSED',
          'ACTIVE',
        }.contains(key)) {
      return key.replaceAll('_', ' ');
    }
    return 'Unavailable';
  }
  return raw!.trim();
}

class AppLabeledStatus extends StatelessWidget {
  const AppLabeledStatus({
    super.key,
    required this.status,
    this.labels = const {},
    this.compact = false,
  });

  final String? status;
  final Map<String, String> labels;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = displayStatusLabel(status, labels: labels);
    return AppStatusChip(
      label: label,
      compact: compact,
      variant: label == 'Unavailable'
          ? AppChipVariant.neutral
          : chipVariantForStatus(status),
    );
  }
}

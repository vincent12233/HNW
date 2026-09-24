import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../models/account_transaction.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/number_formatters.dart';
import '../app_feedback.dart';
import '../app_card.dart';
import '../app_page_scaffold.dart';

class FundsTab extends StatelessWidget {
  const FundsTab({
    super.key,
    required this.transactions,
    this.onRefresh,
    this.loading = false,
    this.loadFailed = false,
  });

  final List<AccountTransaction> transactions;
  final Future<void> Function()? onRefresh;
  final bool loading;
  final bool loadFailed;

  @override
  Widget build(BuildContext context) {
    if (loading && transactions.isEmpty) {
      return const AppLoadingView(message: 'Loading account activity');
    }
    if (loadFailed && transactions.isEmpty) {
      return AppErrorView(
        title: 'Unable to load account activity. Please try again.',
        onRetry: onRefresh == null || loading ? null : () => onRefresh!(),
      );
    }
    return Column(
      children: [
        if (loading) const LinearProgressIndicator(),
        if (loadFailed)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const AppText(
                  'Unable to refresh account activity. Previously loaded records are shown.',
                ),
                if (onRefresh != null)
                  TextButton.icon(
                    onPressed: loading ? null : () => onRefresh!(),
                    icon: const Icon(Icons.refresh),
                    label: const AppText('Retry'),
                  ),
              ],
            ),
          ),
        Expanded(child: _buildRecords(context)),
      ],
    );
  }

  Widget _buildRecords(BuildContext context) {
    if (transactions.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No fund transactions',
          message:
              'Deposits credited by finance and withdrawals you submit will appear here.',
          action: onRefresh == null
              ? null
              : OutlinedButton.icon(
                  onPressed: () {
                    onRefresh!();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const AppText('Refresh account activity'),
                ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.page,
        itemCount: transactions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          final credit = transaction.amount >= 0;
          return AppCard(
            padding: AppSpacing.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          (credit ? AppColors.gain : AppColors.loss).withValues(
                            alpha: 0.10,
                          ),
                      child: Icon(
                        credit
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        color: credit ? AppColors.gain : AppColors.loss,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppText(
                        transaction.type.replaceAll('_', ' '),
                        style: AppTypography.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (transaction.note?.isNotEmpty == true)
                  AppText(transaction.note!),
                const SizedBox(height: 6),
                AppText(
                  '${transaction.createdAt.toLocal()}',
                  style: AppTypography.caption,
                ),
                const Divider(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      '${credit ? '+' : ''}${formatPrice(transaction.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: credit ? AppColors.gain : AppColors.loss,
                      ),
                    ),
                    AppText(
                      'Balance ${formatPrice(transaction.balanceAfter)}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

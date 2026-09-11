import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/account_transaction.dart';
import '../../utils/number_formatters.dart';

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
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        if (loading) const LinearProgressIndicator(),
        if (loadFailed)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AppText(
                  transactions.isEmpty
                      ? 'Unable to load account activity. Please try again.'
                      : 'Unable to refresh account activity. Previously loaded records are shown.',
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
        if (!(loadFailed && transactions.isEmpty))
          Expanded(child: _buildRecords(context)),
      ],
    );
  }

  Widget _buildRecords(BuildContext context) {
    if (transactions.isEmpty) {
      final theme = Theme.of(context);
      return RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
          children: [
            const SizedBox(height: 72),
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.72),
            ),
            const SizedBox(height: 16),
            AppText(
              'No fund transactions',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            AppText(
              'Deposits, withdrawals and other account entries will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: 18),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                    onRefresh!();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const AppText('Refresh account activity'),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          final credit = transaction.amount >= 0;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            (credit ? AppConfig.gainColor : AppConfig.lossColor)
                                .withValues(alpha: 0.10),
                        child: Icon(
                          credit
                              ? Icons.south_west_rounded
                              : Icons.north_east_rounded,
                          color: credit
                              ? AppConfig.gainColor
                              : AppConfig.lossColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppText(
                          transaction.type.replaceAll('_', ' '),
                          style: const TextStyle(fontWeight: FontWeight.w700),
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
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const Divider(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        '${credit ? '+' : ''}${formatPrice(transaction.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: credit
                              ? AppConfig.gainColor
                              : AppConfig.lossColor,
                        ),
                      ),
                      AppText(
                        'Balance ${formatPrice(transaction.balanceAfter)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

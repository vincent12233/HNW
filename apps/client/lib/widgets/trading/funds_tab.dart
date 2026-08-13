import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/account_transaction.dart';
import '../../utils/number_formatters.dart';

class FundsTab extends StatelessWidget {
  const FundsTab({super.key, required this.transactions});

  final List<AccountTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(child: Text('No fund transactions'));
    }
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          final credit = transaction.amount >= 0;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    (credit ? AppConfig.gainColor : AppConfig.lossColor)
                        .withValues(alpha: 0.10),
                child: Icon(
                  credit ? Icons.south_west_rounded : Icons.north_east_rounded,
                  color: credit ? AppConfig.gainColor : AppConfig.lossColor,
                ),
              ),
              title: Text(
                transaction.type.replaceAll('_', ' '),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                transaction.note?.isNotEmpty == true
                    ? transaction.note!
                    : '${transaction.createdAt.toLocal()}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${credit ? '+' : ''}${formatPrice(transaction.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: credit ? AppConfig.gainColor : AppConfig.lossColor,
                    ),
                  ),
                  Text(
                    'Bal ${formatPrice(transaction.balanceAfter)}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
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

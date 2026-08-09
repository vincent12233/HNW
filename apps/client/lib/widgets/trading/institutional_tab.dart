import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/institutional_opportunity.dart';
import '../../utils/number_formatters.dart';

class InstitutionalTab extends StatelessWidget {
  const InstitutionalTab({super.key, required this.stocks, this.onOpen});

  final List<InstitutionalStock> stocks;
  final ValueChanged<InstitutionalStock>? onOpen;

  @override
  Widget build(BuildContext context) {
    if (stocks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.business_center_outlined,
                size: 64,
                color: Colors.black38,
              ),
              SizedBox(height: 16),
              Text(
                'No institutional stocks available',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Institutional stock opportunities will appear here when available.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: stocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final stock = stocks[index];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFE8EEFA),
                    child: Text(
                      stock.symbol.substring(0, 1),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppConfig.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock.symbol,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          stock.companyName,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatPrice(stock.price),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Min. ${stock.minimumQuantity} shares',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  if (onOpen != null)
                    FilledButton(
                      onPressed: () => onOpen!(stock),
                      child: const Text('View'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

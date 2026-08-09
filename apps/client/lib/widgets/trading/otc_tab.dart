import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/institutional_opportunity.dart';
import '../../utils/number_formatters.dart';

class OtcTab extends StatelessWidget {
  const OtcTab({super.key, required this.opportunities});

  final List<InstitutionalStock> opportunities;

  @override
  Widget build(BuildContext context) {
    final items = opportunities.isEmpty
        ? const [
            InstitutionalStock(
              id: 'OTC001',
              symbol: 'HDFCLIFE-BLK',
              companyName: 'HDFC Life Insurance Block Deal',
              price: 642.20,
              minimumQuantity: 2500,
              status: 'Indicative',
            ),
            InstitutionalStock(
              id: 'OTC002',
              symbol: 'TITAN-PRE',
              companyName: 'Titan Pre-Open Cross',
              price: 3580.00,
              minimumQuantity: 1000,
              status: 'Negotiable',
            ),
          ]
        : opportunities;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEFA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.handshake_outlined,
                        color: AppConfig.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.symbol,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item.status,
                      style: const TextStyle(
                        color: AppConfig.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _value(
                        'Indicative Price',
                        formatPrice(item.price),
                      ),
                    ),
                    Expanded(
                      child: _value(
                        'Min. Quantity',
                        formatNumber(item.minimumQuantity),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${item.symbol} enquiry sent to relationship desk',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Request Quote'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _value(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black45, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

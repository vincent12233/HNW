import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_config.dart';

class LearningCenterPage extends StatelessWidget {
  const LearningCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    const lessons = <(String, String, IconData)>[
      (
        'Getting started',
        'Learn how watchlists, quotes and market sessions work.',
        Icons.rocket_launch_outlined,
      ),
      (
        'Placing an order',
        'Review quantity, price, available balance and order status.',
        Icons.swap_horiz_rounded,
      ),
      (
        'Understanding risk',
        'Prices can move quickly. Review product and settlement risks.',
        Icons.shield_outlined,
      ),
      (
        'Inst., OTC and IPO',
        'Understand eligibility, review, allocation and settlement flows.',
        Icons.account_balance_outlined,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Learning Center')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: lessons.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final lesson = lessons[index];
          return Card(
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: AppConfig.primaryColor.withValues(alpha: .1),
                child: Icon(lesson.$3, color: AppConfig.primaryColor),
              ),
              title: Text(
                lesson.$1,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Text(lesson.$2, style: const TextStyle(height: 1.5)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ReferralPage extends StatelessWidget {
  const ReferralPage({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final resolvedCode = code.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Refer & Earn')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF073B91), Color(0xFF0878F9)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                SizedBox(height: 16),
                Text(
                  'Invite friends',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Rewards are credited only after the invited account meets the displayed eligibility rules.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (resolvedCode.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.schedule_rounded, color: Color(0xFFF59E0B)),
                title: Text('Referral program is not active'),
                subtitle: Text(
                  'Your invitation code will appear here after the program is enabled for your account.',
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your referral code'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            resolvedCode,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: resolvedCode),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Referral code copied'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copy'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class OffersPage extends StatelessWidget {
  const OffersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coupons')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Color(0xFFF3E8FF),
                child: Icon(
                  Icons.confirmation_number_outlined,
                  color: Color(0xFF7C3AED),
                  size: 34,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'No active coupons',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 7),
              Text(
                'Eligible offers issued by the service will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

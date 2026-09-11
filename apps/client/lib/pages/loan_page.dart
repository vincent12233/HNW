import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../services/client_account_service.dart';
import '../utils/number_formatters.dart';

class LoanPage extends StatefulWidget {
  const LoanPage({super.key, this.service});
  final ClientAccountService? service;
  @override
  State<LoanPage> createState() => _LoanPageState();
}

class _LoanPageState extends State<LoanPage> {
  late final service = widget.service ?? ClientAccountService();
  List<Map<String, dynamic>> rows = [];
  bool loading = true, submitting = false;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    final request = ++generation;
    setState(() => loading = true);
    try {
      final result = await service.loans();
      if (mounted && request == generation) {
        setState(() {
          rows = result;
          error = null;
        });
      }
    } catch (_) {
      if (mounted && request == generation) {
        setState(() => error = 'Unable to load loan applications');
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> apply() async {
    if (submitting ||
        loading ||
        error != null ||
        rows.any((r) => r['status'] == 'PENDING')) {
      return;
    }
    setState(() => submitting = true);
    try {
      await service.applyForLoan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Application submitted. Please wait for review.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'Unable to confirm application. Refresh to check its status.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        await load();
        if (mounted) setState(() => submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('Loan Applications')),
    body: loading && rows.isEmpty && error == null
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (loading) const LinearProgressIndicator(),
                if (error != null) ...[
                  AppText(error!),
                  TextButton(
                    onPressed: loading ? null : load,
                    child: const AppText('Retry'),
                  ),
                ],
                FilledButton.icon(
                  onPressed:
                      submitting ||
                          loading ||
                          error != null ||
                          rows.any((r) => r['status'] == 'PENDING')
                      ? null
                      : apply,
                  icon: const Icon(Icons.request_quote_outlined),
                  label: AppText(
                    submitting ? 'Submitting...' : 'Apply for a Loan',
                  ),
                ),
                const SizedBox(height: 20),
                if (rows.isEmpty && error == null)
                  const AppText('No loan applications'),
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      row['status'] == 'PENDING'
                          ? Icons.hourglass_empty
                          : Icons.description_outlined,
                    ),
                    title: Text('${row['orderNo']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          const {
                                'PENDING': 'Pending Review',
                                'REJECTED': 'Rejected',
                                'DISBURSED': 'Disbursed',
                                'APPROVED': 'Approved',
                                'REPAID': 'Repaid',
                                'PARTIAL_REPAID': 'Partially Repaid',
                                'OVERDUE': 'Overdue',
                              }[row['status']] ??
                              'Status unavailable',
                        ),
                        if (row['approvedAmount'] != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppText('Approved Amount'),
                              Text(_approvedAmount(row['approvedAmount'])),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
  );

  String _approvedAmount(Object? value) {
    final amount = double.tryParse('$value');
    return amount == null || !amount.isFinite || amount < 0
        ? '--'
        : formatPrice(amount);
  }
}

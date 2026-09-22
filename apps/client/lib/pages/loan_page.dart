import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../services/client_account_service.dart';
import '../theme/app_spacing.dart';
import '../utils/client_error_message.dart';
import '../utils/number_formatters.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_status_label.dart';
import '../widgets/record_detail_sheet.dart';

const _loanStatusLabels = {
  'PENDING': 'Pending Review',
  'REJECTED': 'Rejected',
  'DISBURSED': 'Disbursed',
  'APPROVED': 'Approved',
  'REPAID': 'Repaid',
  'PARTIAL_REPAID': 'Partially Repaid',
  'OVERDUE': 'Overdue',
};

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
  Future<void>? _inFlight;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() {
    final pending = _inFlight;
    if (pending != null) return pending;
    if (!mounted) return Future.value();
    final request = ++generation;
    final future = _loadOnce(request);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<void> _loadOnce(int request) async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final result = await service.loans();
      if (mounted && request == generation) {
        setState(() {
          rows = result;
          error = null;
        });
      }
    } catch (err) {
      if (mounted && request == generation) {
        setState(
          () => error = clientErrorMessage(
            err,
            fallback: 'Unable to load loan applications',
          ),
        );
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  bool get _hasPending => rows.any((r) => r['status'] == 'PENDING');

  Future<void> apply() async {
    if (submitting || loading || error != null || _hasPending) {
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
      await load();
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
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (loading && rows.isEmpty && error == null) {
      body = const AppLoadingView(message: 'Loading loan applications');
    } else if (error != null && rows.isEmpty) {
      body = AppErrorView(
        title: 'Unable to load loan applications',
        message: error,
        onRetry: load,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: AppSpacing.page,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppErrorView(
                  title: error!,
                  onRetry: load,
                  compact: true,
                ),
              ),
            AppPrimaryButton(
              label: 'Apply for a Loan',
              icon: Icons.request_quote_outlined,
              loading: submitting,
              onPressed: submitting || loading || error != null || _hasPending
                  ? null
                  : apply,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (rows.isEmpty)
              const AppEmptyState(
                compact: true,
                title: 'No loan applications',
                message:
                    'Submit a request for finance review. Approval is not automatic.',
                icon: Icons.request_quote_outlined,
              )
            else
              for (final row in rows) _loanCard(row),
          ],
        ),
      );
    }

    return AppPageScaffold(
      appBar: AppBar(
        title: const AppText(
          'Loan Applications',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: body,
    );
  }

  Widget _loanCard(Map<String, dynamic> row) {
    final status = row['status']?.toString();
    final orderNo = row['orderNo']?.toString() ?? '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => showRecordDetailSheet(
        context,
        title: orderNo.isEmpty ? 'Loan application' : orderNo,
        status: AppStatusChip(
          label: _statusText(status),
          variant: _statusText(status) == 'Status unavailable'
              ? AppChipVariant.neutral
              : chipVariantForStatus(status),
        ),
        rows: [
          ('Reference', orderNo.isEmpty ? 'Unavailable' : orderNo),
          ('Status', _statusText(status)),
          ('Approved amount', _approvedAmount(row['approvedAmount'])),
          (
            'Outstanding',
            row.containsKey('outstandingAmount')
                ? _approvedAmount(row['outstandingAmount'])
                : 'Unavailable',
          ),
          (
            'Submitted',
            formatAppDateTime(
              DateTime.tryParse(row['createdAt']?.toString() ?? ''),
            ),
          ),
        ],
      ),
      leading: Icon(
        status == 'PENDING'
            ? Icons.hourglass_empty
            : Icons.description_outlined,
      ),
      title: Text(
        orderNo.isEmpty ? 'Unavailable' : orderNo,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(_statusText(status)),
          if (row['approvedAmount'] != null) ...[
            const AppText('Approved Amount'),
            Text(_approvedAmount(row['approvedAmount'])),
          ],
        ],
      ),
    );
  }

  String _statusText(String? status) {
    final key = (status ?? '').trim().toUpperCase();
    return _loanStatusLabels[key] ?? 'Status unavailable';
  }

  String _approvedAmount(Object? value) {
    final amount = double.tryParse('$value');
    return amount == null || !amount.isFinite || amount < 0
        ? '--'
        : formatPrice(amount);
  }
}

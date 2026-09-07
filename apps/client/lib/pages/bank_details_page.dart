import 'package:flutter/material.dart';
import '../app_config.dart';
import '../services/client_account_service.dart';
import '../utils/client_error_message.dart';

class BankDetailsPage extends StatefulWidget {
  const BankDetailsPage({super.key, this.onContinue, this.initial = const {}});
  final ValueChanged<Map<String, String>>? onContinue;
  final Map<String, String> initial;

  @override
  State<BankDetailsPage> createState() => _BankDetailsPageState();
}

class _BankDetailsPageState extends State<BankDetailsPage> {
  final _form = GlobalKey<FormState>();
  final _holder = TextEditingController();
  final _number = TextEditingController();
  final _confirm = TextEditingController();
  final _ifsc = TextEditingController();
  final _bank = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _holder.text = widget.initial['accountHolder'] ?? '';
    _number.text = widget.initial['accountNumber'] ?? '';
    _confirm.text = _number.text;
    _ifsc.text = widget.initial['ifscCode'] ?? '';
    _bank.text = widget.initial['bankName'] ?? '';
  }

  @override
  void dispose() {
    for (final controller in [_holder, _number, _confirm, _ifsc, _bank]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (widget.onContinue != null) {
      widget.onContinue!({'bankName': _bank.text.trim(), 'accountHolder': _holder.text.trim(), 'accountNumber': _number.text.trim(), 'ifscCode': _ifsc.text.trim().toUpperCase()});
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ClientAccountService().addBank({
        'bankName': _bank.text.trim(),
        'accountHolder': _holder.text.trim(),
        'accountNumber': _number.text.trim(),
        'ifscCode': _ifsc.text.trim().toUpperCase(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = clientErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Bank Details')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.account_balance,
                        color: AppConfig.primaryColor,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Bank Account',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Enter your bank details for withdrawals.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _field(
                  'Account Holder Name',
                  'Enter full name as per bank record',
                  _holder,
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter the account holder name'
                      : null,
                ),
                _field(
                  'Account Number',
                  'Enter your bank account number',
                  _number,
                  numeric: true,
                  validator: (value) =>
                      !RegExp(r'^\d{6,18}$').hasMatch(value?.trim() ?? '')
                      ? 'Enter 6 to 18 digits'
                      : null,
                ),
                _field(
                  'Confirm Account Number',
                  'Re-enter your account number',
                  _confirm,
                  numeric: true,
                  validator: (value) => value?.trim() != _number.text.trim()
                      ? 'Account numbers do not match'
                      : null,
                ),
                _field(
                  widget.onContinue != null ? 'IFSC Code (Optional)' : 'IFSC Code',
                  'Enter the 11-character IFSC code',
                  _ifsc,
                  validator: (value) => widget.onContinue != null && (value?.trim().isEmpty ?? true) ? null :
                      !RegExp(
                        r'^[A-Z]{4}0[A-Z0-9]{6}$',
                      ).hasMatch(value?.trim().toUpperCase() ?? '')
                      ? 'Enter a valid IFSC code'
                      : null,
                ),
                _field(
                  'Bank Name',
                  'Enter your bank name',
                  _bank,
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter your bank name'
                      : null,
                ),
                const SizedBox(height: 8),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.lock_outline,
                    color: AppConfig.primaryColor,
                    size: 20,
                  ),
                  title: Text(
                    'Your bank details are used for account verification and withdrawals.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: AppConfig.lossColor),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _field(
    String label,
    String hint,
    TextEditingController controller, {
    bool numeric = false,
    required FormFieldValidator<String> validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: !_saving,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(hintText: hint),
          validator: validator,
        ),
      ],
    ),
  );
}

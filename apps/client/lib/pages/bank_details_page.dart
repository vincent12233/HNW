import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/auth_layout.dart';
import '../services/client_account_service.dart';
import '../utils/client_error_message.dart';
import '../widgets/onboarding_widgets.dart';

class BankDetailsPage extends StatefulWidget {
  const BankDetailsPage({super.key, this.onContinue, this.initial = const {}});
  final ValueChanged<Map<String, String>>? onContinue;
  final Map<String, String> initial;

  @override
  State<BankDetailsPage> createState() => _BankDetailsPageState();
}

class _BankDetailsPageState extends State<BankDetailsPage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _holder = TextEditingController();
  final _number = TextEditingController();
  final _confirm = TextEditingController();
  final _ifsc = TextEditingController();
  final _bank = TextEditingController();
  bool _saving = false;
  bool _hideNumber = true;
  bool _hideConfirm = true;
  String? _error;

  bool get _kycFlow => widget.onContinue != null;

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
    _scroll.dispose();
    for (final controller in [_holder, _number, _confirm, _ifsc, _bank]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) return;
    final payload = <String, String>{
      'bankName': _bank.text.trim(),
      'accountHolder': _holder.text.trim(),
      'accountNumber': _number.text.trim(),
      'ifscCode': _ifsc.text.trim().toUpperCase(),
    };
    if (widget.onContinue != null) {
      setState(() => _saving = true);
      widget.onContinue!(payload);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ClientAccountService().addBank(payload);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = clientErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxWidth = AuthLayout.formMaxWidth(media.size.width);
    final horizontal = AuthLayout.horizontalPadding(media.size.width);

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: AuthLayout.pageBackground,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: AuthLayout.pageBackground,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const AppText('Bank Details'),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: SizedBox(
                      width: double.infinity,
                      child: Form(
                        key: _form,
                        child: SingleChildScrollView(
                          key: const ValueKey('kyc-bank-scroll'),
                          controller: _scroll,
                          clipBehavior: Clip.hardEdge,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            AuthLayout.pagePaddingTop,
                            horizontal,
                            AuthLayout.fieldGap + media.viewInsets.bottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_kycFlow)
                                const KycStepIntro(
                                  current: 5,
                                  total: 6,
                                  title: 'Add Bank Account',
                                  subtitle:
                                      'Enter the bank account that will be used for withdrawals after manual review.',
                                )
                              else ...[
                                Text(
                                  'Add Bank Account',
                                  style: AuthLayout.title.copyWith(fontSize: 24),
                                ),
                                const SizedBox(height: AuthLayout.titleGap),
                                const AppText(
                                  'Enter your bank details for withdrawals. Adding an account does not mean the bank has verified it.',
                                  style: AuthLayout.subtitle,
                                ),
                              ],
                              const SizedBox(height: AuthLayout.fieldGap),
                              const VerificationBanner(
                                tone: KycBannerTone.info,
                                icon: Icons.account_balance_outlined,
                                title: 'Bank details for this account',
                                subtitle:
                                    'These details are stored with your application. They are not checked instantly against a bank.',
                              ),
                              const SizedBox(height: AuthLayout.sectionGap),
                              _field(
                                'Account Holder Name',
                                'Enter full name as per bank record',
                                _holder,
                                keyboard: TextInputType.name,
                                capitalization: TextCapitalization.words,
                                validator: (value) =>
                                    (value?.trim().length ?? 0) < 2
                                    ? 'Enter the account holder name'
                                    : null,
                              ),
                              _field(
                                'Account Number',
                                'Enter your bank account number',
                                _number,
                                numeric: true,
                                obscure: _hideNumber,
                                onToggleObscure: () => setState(
                                  () => _hideNumber = !_hideNumber,
                                ),
                                validator: (value) =>
                                    !RegExp(
                                      r'^\d{6,18}$',
                                    ).hasMatch(value?.trim() ?? '')
                                    ? 'Enter 6 to 18 digits'
                                    : null,
                              ),
                              _field(
                                'Confirm Account Number',
                                'Re-enter your account number',
                                _confirm,
                                numeric: true,
                                obscure: _hideConfirm,
                                onToggleObscure: () => setState(
                                  () => _hideConfirm = !_hideConfirm,
                                ),
                                validator: (value) =>
                                    value?.trim() != _number.text.trim()
                                    ? 'Account numbers do not match'
                                    : null,
                              ),
                              _field(
                                _kycFlow
                                    ? 'IFSC Code (Optional)'
                                    : 'IFSC Code',
                                'Enter the 11-character IFSC code',
                                _ifsc,
                                keyboard: TextInputType.visiblePassword,
                                capitalization: TextCapitalization.characters,
                                validator: (value) =>
                                    _kycFlow && (value?.trim().isEmpty ?? true)
                                    ? null
                                    : !RegExp(
                                        r'^[A-Z]{4}0[A-Z0-9]{6}$',
                                      ).hasMatch(
                                        value?.trim().toUpperCase() ?? '',
                                      )
                                    ? 'Enter a valid IFSC code'
                                    : null,
                              ),
                              _field(
                                'Bank Name',
                                'Enter your bank name',
                                _bank,
                                keyboard: TextInputType.name,
                                capitalization: TextCapitalization.words,
                                validator: (value) =>
                                    (value?.trim().length ?? 0) < 2
                                    ? 'Enter your bank name'
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              const VerificationBanner(
                                tone: KycBannerTone.info,
                                icon: Icons.lock_outline,
                                title: 'How these details are used',
                                subtitle:
                                    'Your bank details are used for account verification and withdrawals.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
                              KycFlowFooter(
                label: 'Continue',
                busy: _saving,
                errorText: _error,
                helper: _kycFlow
                    ? 'Used for identity verification'
                    : 'Saved for withdrawals after you submit. This is not a completed bank verification.',
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    String hint,
    TextEditingController controller, {
    bool numeric = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
    required FormFieldValidator<String> validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      obscureText: obscure,
      keyboardType: numeric ? TextInputType.number : keyboard,
      textCapitalization: capitalization,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const <String>[],
      inputFormatters: numeric
          ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
          : label.startsWith('IFSC')
          ? <TextInputFormatter>[
              TextInputFormatter.withFunction(
                (oldValue, newValue) =>
                    newValue.copyWith(text: newValue.text.toUpperCase()),
              ),
              LengthLimitingTextInputFormatter(11),
            ]
          : null,
      textInputAction: controller == _bank
          ? TextInputAction.done
          : TextInputAction.next,
      onFieldSubmitted: (_) {
        if (controller == _bank) {
          FocusScope.of(context).unfocus();
          _save();
        } else {
          FocusScope.of(context).nextFocus();
        }
      },
      style: const TextStyle(height: 1.2, letterSpacing: 0),
      decoration: onboardingInput(
        label,
        helperText: hint,
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                onPressed: onToggleObscure,
                tooltip: obscure ? 'Show account number' : 'Hide account number',
                constraints: const BoxConstraints(
                  minWidth: AppMotion.tapTarget,
                  minHeight: AppMotion.tapTarget,
                ),
                icon: Icon(
                  obscure ? Icons.visibility : Icons.visibility_off,
                  size: AppMotion.iconField,
                ),
              ),
      ),
      validator: validator,
    ),
  );
}

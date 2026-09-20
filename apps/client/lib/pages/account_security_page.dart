import '../widgets/app_page_scaffold.dart';
import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/client_account_service.dart';
import '../services/auth_service.dart';
import '../services/session_expiry_service.dart';
import '../theme/app_motion.dart';
import '../utils/client_error_message.dart';

class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({
    super.key,
    this.withdrawalPin = false,
    this.accountService,
  });
  final bool withdrawalPin;
  final ClientAccountService? accountService;
  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _currentPin = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  late final _service = widget.accountService ?? ClientAccountService();
  final _visible = <TextEditingController>{};
  bool _loading = true;
  bool _saving = false;
  bool _configured = false;
  bool _loadFailed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _error = null;
    });
    try {
      final configured =
          widget.withdrawalPin && await _service.hasWithdrawalPin();
      if (mounted) {
        setState(() {
          _configured = configured;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = clientErrorMessage(error);
          _loadFailed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [_password, _currentPin, _next, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _loadFailed || _form.currentState?.validate() != true) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.withdrawalPin) {
        await _service.changeWithdrawalPin(
          _password.text,
          _currentPin.text,
          _next.text,
        );
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText('Withdrawal PIN saved')),
          );
          Navigator.pop(context, true);
        }
      } else {
        await _service.changePassword(_password.text, _next.text);
        await AuthService().clearSession();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: AppText('Password changed. Please sign in again'),
            ),
          );
        }
        await SessionExpiryService().expire();
      }
    } catch (error) {
      if (mounted) setState(() => _error = clientErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool pin = false,
    bool confirmation = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: controller,
      obscureText: !_visible.contains(controller),
      enabled: !_saving,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: confirmation
          ? TextInputAction.done
          : TextInputAction.next,
      onFieldSubmitted: (_) {
        if (confirmation) {
          FocusScope.of(context).unfocus();
          _save();
        } else {
          FocusScope.of(context).nextFocus();
        }
      },
      keyboardType: pin ? TextInputType.number : TextInputType.visiblePassword,
      inputFormatters: pin
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ]
          : null,
      decoration: InputDecoration(
        labelText: tr(label),
        suffixIcon: IconButton(
          tooltip: _visible.contains(controller) ? tr('Hide') : tr('Show'),
          onPressed: () => setState(() {
            if (!_visible.add(controller)) _visible.remove(controller);
          }),
          constraints: const BoxConstraints(
            minWidth: AppMotion.tapTarget,
            minHeight: AppMotion.tapTarget,
          ),
          icon: Icon(
            _visible.contains(controller)
                ? Icons.visibility_off
                : Icons.visibility,
            size: AppMotion.iconField,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return tr('This field is required');
        if (pin && !RegExp(r'^\d{6}$').hasMatch(value)) {
          return tr('Enter a 6-digit PIN');
        }
        if (confirmation && value != _next.text) {
          return tr('Values do not match');
        }
        if (!pin &&
            controller == _next &&
            (value.length < 8 || value.length > 72)) {
          return tr('Use 8-72 characters');
        }
        if (!pin && controller == _next && value == _password.text) {
          return tr('New password must be different');
        }
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AppPageScaffold(
      appBar: AppBar(
        title: AppText(
          widget.withdrawalPin ? 'Withdrawal PIN' : 'Change Password',
        ),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  AppText('Loading security settings'),
                ],
              ),
            )
          : _loadFailed
          ? AppEmptyState(
              title: 'Unable to load security settings',
              message: _error,
              onRetry: _load,
              icon: Icons.cloud_off_outlined,
            )
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _field(_password, 'Current login password'),
                  if (widget.withdrawalPin && _configured)
                    _field(_currentPin, 'Current withdrawal PIN', pin: true),
                  _field(
                    _next,
                    widget.withdrawalPin
                        ? 'New withdrawal PIN'
                        : 'New login password',
                    pin: widget.withdrawalPin,
                  ),
                  _field(
                    _confirm,
                    widget.withdrawalPin
                        ? 'Confirm withdrawal PIN'
                        : 'Confirm new password',
                    pin: widget.withdrawalPin,
                    confirmation: true,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AppText(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  SizedBox(
                    height: AppMotion.tapTarget,
                    child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const AppText('Save changes'),
                  ),
                  ),
                ],
              ),
            ),
    ),
  );
}

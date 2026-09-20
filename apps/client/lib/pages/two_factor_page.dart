import '../widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_language.dart';
import '../services/auth_service.dart';
import '../services/client_account_service.dart';
import '../services/session_expiry_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/client_error_message.dart';

class TwoFactorPage extends StatefulWidget {
  const TwoFactorPage({super.key, this.accountService});
  final ClientAccountService? accountService;
  @override
  State<TwoFactorPage> createState() => _TwoFactorPageState();
}

class _TwoFactorPageState extends State<TwoFactorPage> {
  final _password = TextEditingController(), _code = TextEditingController();
  late final _service = widget.accountService ?? ClientAccountService();
  bool _busy = true;
  bool? _enabled;
  bool _hidePassword = true;
  String? _secret, _error;
  List<String>? _recovery;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await _service.twoFactorStatus();
      if (mounted) setState(() => _enabled = status['enabled'] == true);
    } catch (error) {
      if (mounted) setState(() => _error = clientErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService().clearSession();
    SessionExpiryService().expire();
  }

  Future<void> _submit() async {
    if (_busy || _enabled == null || _recovery != null) return;
    if (_secret == null && _password.text.isEmpty) {
      setState(() => _error = 'Enter your current login password');
      return;
    }
    if (_secret != null && !RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _error = 'Enter a 6-digit authenticator code');
      return;
    }
    if (_enabled == true && _code.text.trim().isEmpty) {
      setState(() => _error = 'Enter an authenticator or recovery code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final action = _enabled == true
          ? 'disable'
          : _secret == null
          ? 'setup'
          : 'confirm';
      final result = await _service.twoFactorAction(
        action,
        password: _password.text,
        code: _code.text.trim(),
      );
      if (!mounted) return;
      if (action == 'setup') {
        setState(() {
          _secret = result['secret'] as String;
          _password.clear();
          _code.clear();
        });
      } else if (action == 'confirm') {
        setState(() {
          _secret = null;
          _recovery = List<String>.from(result['recoveryCodes'] as List);
        });
      } else {
        await _signOut();
      }
    } catch (error) {
      if (mounted) setState(() => _error = clientErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _recovery == null,
    child: AppPageScaffold(
      appBar: AppBar(
        title: const AppText('Two-Factor Authentication'),
        automaticallyImplyLeading: _recovery == null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: AppText(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (!_busy && _enabled == null)
                AppEmptyState(
                  title: 'Unable to load authenticator settings',
                  message: _error,
                  onRetry: _load,
                  icon: Icons.cloud_off_outlined,
                ),
              if (_recovery != null) ...[
                const Icon(
                  Icons.verified_user_outlined,
                  size: 48,
                  color: Colors.teal,
                ),
                const SizedBox(height: 20),
                const AppText(
                  'Recovery codes',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const AppText(
                  'Store these recovery codes securely. Each recovery code can be used once if you lose access to your authenticator app. These are not text-message or Aadhaar one-time passwords.',
                ),
                const SizedBox(height: 20),
                SelectableText(
                  _recovery!.join('\n'),
                  style: const TextStyle(fontFamily: 'monospace', height: 2),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _signOut,
                  child: const AppText('Saved. Sign in again'),
                ),
              ] else if (_enabled != null) ...[
                AppText(
                  _enabled! ? 'Enabled' : 'Disabled',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const AppText(
                  'Authenticator app codes and recovery codes are optional. Sign-in still uses your mobile number and password. These are not text-message or Aadhaar one-time passwords.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 20),
                if (_secret == null)
                  TextField(
                    controller: _password,
                    obscureText: _hidePassword,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: tr('Current login password'),
                      suffixIcon: IconButton(
                        tooltip: _hidePassword ? tr('Show') : tr('Hide'),
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                if (_secret != null) ...[
                  const AppText('Authenticator setup key'),
                  const SizedBox(height: 12),
                  SelectableText(_secret!),
                  IconButton(
                    tooltip: tr('Copy setup key'),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: _secret!)),
                    icon: const Icon(Icons.copy),
                  ),
                ],
                if (_enabled! || _secret != null) ...[
                  const SizedBox(height: 18),
                  TextField(
                    controller: _code,
                    enabled: !_busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: _secret != null
                        ? TextInputType.number
                        : TextInputType.text,
                    inputFormatters: _secret != null
                        ? [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ]
                        : null,
                    decoration: InputDecoration(
                      labelText: tr(
                        _enabled!
                            ? 'Authenticator or recovery code'
                            : 'Authenticator app code',
                      ),
                      helperText: _enabled!
                          ? 'Enter a 6-digit authenticator app code or a recovery code.'
                          : 'Enter the 6-digit authenticator app code.',
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: AppMotion.tapTarget,
                  child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: AppText(
                    _enabled!
                        ? 'Disable'
                        : _secret == null
                        ? 'Set up authenticator'
                        : 'Confirm and enable',
                  ),
                ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

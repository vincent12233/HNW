import '../l10n/app_language.dart';
import 'dart:async';
import 'dart:convert';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/auth_layout.dart';
import '../utils/client_error_message.dart';
import '../widgets/international_phone_field.dart';
import '../widgets/onboarding_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final phone = TextEditingController(),
      message = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  String? phoneError;
  final storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      migrateOnAlgorithmChange: true,
      migrateWithBackup: true,
    ),
  );
  Country country = Country.parse('IN');
  String? token, error;
  bool busy = false,
      polling = false,
      ready = false,
      obscure = true,
      obscureConfirm = true,
      closed = false,
      succeeded = false;
  List<Map<String, dynamic>> messages = [];
  Timer? timer;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      token = await storage.read(key: 'recovery_token');
      if (!mounted) return;
      if (token != null) {
        await _poll();
        _startPolling();
      }
    } catch (e) {
      if (mounted) setState(() => error = clientErrorMessage(e));
    } finally {
      if (mounted) setState(() => ready = true);
    }
  }

  void _startPolling() {
    timer?.cancel();
    if (!mounted || token == null || closed) return;
    timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  Future<dynamic> _request(String path, {Map<String, dynamic>? body}) async {
    final headers = {
      'Content-Type': 'application/json',
      'x-recovery-token': ?token,
    };
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/recovery/$path');
    final response =
        await (body == null
                ? http.get(uri, headers: headers)
                : http.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      await storage.delete(key: 'recovery_token');
      token = null;
      timer?.cancel();
      throw const AuthException('Please reconnect to customer support');
    }
    final data = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        data is Map
            ? data['message']?.toString() ?? 'Request failed'
            : 'Request failed',
      );
    }
    return data;
  }

  Future<void> _poll() async {
    if (polling || token == null || !mounted) return;
    polling = true;
    try {
      final data = await _request('messages');
      if (mounted) {
        setState(() {
          messages = (data['messages'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          closed = data['status'] == 'CLOSED';
          if (closed) timer?.cancel();
          error = null;
        });
      }
    } catch (e) {
      final stored = await storage.read(key: 'recovery_token');
      if (mounted) {
        setState(() {
          error = clientErrorMessage(e);
          if (stored == null) token = null;
        });
      }
    } finally {
      polling = false;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || succeeded) return;
    setState(() {
      busy = true;
      error = null;
      phoneError = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = clientErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _connect() async {
    if (busy || succeeded) return;
    final number = internationalPhone(phone.text, country.countryCode);
    if (number == null) {
      setState(() {
        phoneError = 'Enter your registered Indian mobile number';
        error = null;
      });
      return;
    }
    await _run(() async {
      final data = await _request('open', body: {'phone': number});
      token = data['token'] as String;
      await storage.write(key: 'recovery_token', value: token);
      if (!mounted) return;
      await _poll();
      _startPolling();
    });
  }

  Future<void> _send() => _run(() async {
    if (message.text.trim().isEmpty) return;
    await _request('messages', body: {'content': message.text.trim()});
    if (!mounted) return;
    message.clear();
    await _poll();
  });
  Future<void> _reset() => _run(() async {
    if (password.text.length < 8 || password.text != confirm.text) {
      throw const AuthException(
        'Enter matching passwords of at least 8 characters',
      );
    }
    await _request(
      'reset',
      body: {'code': code.text.trim(), 'newPassword': password.text},
    );
    await storage.delete(key: 'recovery_token');
    await AuthService().disableBiometricQuickLogin();
    if (!mounted) return;
    timer?.cancel();
    setState(() => succeeded = true);
    await authSuccessPause(context);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: AppText('Password updated. Please log in.')),
    );
    Navigator.pop(context);
  });
  @override
  void dispose() {
    timer?.cancel();
    for (final c in [phone, message, code, password, confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AuthLayout.pageBackground,
    appBar: AppBar(
      backgroundColor: AuthLayout.pageBackground,
      title: const AppText('Customer Support'),
    ),
    resizeToAvoidBottomInset: true,
    body: !ready
        ? const Center(child: CircularProgressIndicator())
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: AuthOutgoingShift(
                  child: AppEntranceScope(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppEntrance(
                          delay: const Duration(milliseconds: 80),
                          offsetY: 8,
                          child: const AuthBrandHeader(),
                        ),
                        const SizedBox(height: 20),
                        AppEntrance(
                          delay: const Duration(milliseconds: 140),
                          offsetY: 10,
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppText(
                                'Password recovery',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                              SizedBox(height: 8),
                              AppText(
                                'Password reset is handled by customer support. After you connect, a support specialist can issue a recovery code. The app does not send an SMS or email code.',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  letterSpacing: 0,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppEntrance(
                          delay: const Duration(milliseconds: 220),
                          offsetY: 8,
                          child: const VerificationBanner(
                            title: 'Customer support recovery',
                            subtitle:
                                'Use Connect to Support with your registered mobile number. A recovery code appears only after support issues one.',
                            icon: Icons.support_agent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (token == null) ...[
                          InternationalPhoneField(
                            controller: phone,
                            country: country,
                            enabled: !busy && !succeeded,
                            lockCountry: true,
                            errorText: phoneError,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _connect(),
                            onCountryChanged: (c) =>
                                setState(() => country = c),
                          ),
                          const SizedBox(height: 16),
                          if (error != null) AuthFormError(message: error!),
                          AuthSubmitButton(
                            label: 'Connect to Support',
                            busy: busy,
                            succeeded: succeeded,
                            onPressed: _connect,
                          ),
                        ] else ...[
                          if (messages.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: AppText(
                                'Waiting for a support agent. A reset code will appear only after support issues one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  letterSpacing: 0,
                                  height: 1.4,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          for (final item in messages)
                            Align(
                              alignment: item['sender'] == 'CLIENT'
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 330,
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: item['sender'] == 'CLIENT'
                                      ? AppColors.brandPrimarySoft
                                      : AppColors.surfaceSecondary,
                                  borderRadius: AppRadius.borderSm,
                                ),
                                child: SelectableText(
                                  item['content'] as String,
                                ),
                              ),
                            ),
                          if (!closed) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: message,
                                    minLines: 1,
                                    maxLines: 4,
                                    maxLength: 2000,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _send(),
                                    decoration: onboardingInput(
                                      'Message',
                                    ).copyWith(counterText: ''),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Send message',
                                  onPressed: busy ? null : _send,
                                  icon: const Icon(
                                    Icons.send,
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 12),
                            const AppText(
                              'Reset Password',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const AppText(
                              'Enter the recovery code issued by support, then choose a new password. This is not an SMS one-time code.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                letterSpacing: 0,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: code,
                              textCapitalization: TextCapitalization.characters,
                              decoration: onboardingInput(
                                'Reset code from support',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: password,
                              obscureText: obscure,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: onboardingInput('New password')
                                  .copyWith(
                                    suffixIcon: AuthPasswordToggle(
                                      obscure: obscure,
                                      onPressed: () =>
                                          setState(() => obscure = !obscure),
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: confirm,
                              obscureText: obscureConfirm,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: onboardingInput('Confirm password')
                                  .copyWith(
                                    suffixIcon: AuthPasswordToggle(
                                      obscure: obscureConfirm,
                                      onPressed: () => setState(
                                        () => obscureConfirm = !obscureConfirm,
                                      ),
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 16),
                            if (error != null) AuthFormError(message: error!),
                            AuthSubmitButton(
                              label: 'Update Password',
                              busy: busy,
                              succeeded: succeeded,
                              onPressed: _reset,
                            ),
                          ] else ...[
                            const AppText('This support request is closed.'),
                            TextButton(
                              onPressed: () async {
                                await storage.delete(key: 'recovery_token');
                                if (mounted) {
                                  setState(() {
                                    token = null;
                                    closed = false;
                                    messages = [];
                                  });
                                }
                              },
                              child: const AppText('New support request'),
                            ),
                          ],
                        ],
                        if (token != null && error != null && closed)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: AuthFormError(message: error!),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
  );
}

import 'package:flutter/material.dart';
import '../app_config.dart';
import '../services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final phone = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController();
  final service = AuthService();
  bool codeSent = false, loading = false, obscure = true;
  String? error;
  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF07111F),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      title: const Text('Forgot Password'),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xE6122034),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.lock_reset_rounded,
                color: AppConfig.primaryColor,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'Reset your password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 22),
              _field(
                phone,
                'Mobile Number',
                Icons.phone_outlined,
                prefix: '+91 ',
              ),
              if (codeSent) ...[
                const SizedBox(height: 14),
                _field(code, '6-digit OTP', Icons.sms_outlined),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration('New password', Icons.lock_outline)
                      .copyWith(
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: loading ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(codeSent ? 'Reset Password' : 'Send OTP'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    String? prefix,
  }) => TextField(
    controller: c,
    keyboardType: TextInputType.phone,
    style: const TextStyle(color: Colors.white),
    decoration: _decoration(label, icon).copyWith(prefixText: prefix),
  );
  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white60),
    prefixIcon: Icon(icon, color: Colors.white70),
    filled: true,
    fillColor: Colors.white.withValues(alpha: .06),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white12),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white12),
    ),
  );
  Future<void> _submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (!codeSent) {
        await service.requestPasswordReset(phone.text);
        if (mounted) setState(() => codeSent = true);
      } else {
        await service.confirmPasswordReset(
          phone: phone.text,
          code: code.text,
          newPassword: password.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password reset successfully')),
          );
          Navigator.pop(context);
        }
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';

import '../app_config.dart';
import '../models/auth_session.dart';
import '../services/auth_service.dart';
import '../services/market_socket_service.dart';
import '../utils/client_error_message.dart';
import '../widgets/app_brand_logo.dart';
import 'forgot_password_page.dart';
import 'legal_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onSignedIn});
  final ValueChanged<AuthSession> onSignedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final authService = AuthService();
  final googleSignIn = GoogleSignIn(
    scopes: const ['email'],
    clientId: AppConfig.googleClientId.isEmpty
        ? null
        : AppConfig.googleClientId,
    serverClientId: AppConfig.googleClientId.isEmpty
        ? null
        : AppConfig.googleClientId,
  );
  bool obscurePassword = true;
  bool isSubmitting = false;
  String? errorText;

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            children: [
              const SizedBox(height: 24),
              const Center(child: AppBrandLogo(size: 60)),
              const SizedBox(height: 12),
              const Text(
                'India Trading',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: AppConfig.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                AppConfig.slogan,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppConfig.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 36),
              _loginCard(),
              const SizedBox(height: 32),
              _legal(),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _loginCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Welcome Back!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF0A1730),
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sign in to continue',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF7A879A)),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration:
              _input(
                'Mobile Number',
                'Enter mobile number',
                Icons.phone_outlined,
              ).copyWith(
                prefixText: '+91  ',
                prefixStyle: const TextStyle(
                  color: Color(0xFF0A1730),
                  fontWeight: FontWeight.w700,
                ),
              ),
        ),
        const SizedBox(height: 13),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => isSubmitting ? null : _submit(),
          decoration:
              _input(
                'Password',
                'Enter your password',
                Icons.lock_outline_rounded,
              ).copyWith(
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => obscurePassword = !obscurePassword),
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFF536278),
                  ),
                ),
              ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: isSubmitting
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ForgotPasswordPage(),
                    ),
                  ),
            child: const Text('Forgot Password?'),
          ),
        ),
        SizedBox(
          height: 53,
          child: FilledButton.icon(
            onPressed: isSubmitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppConfig.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            iconAlignment: IconAlignment.end,
            icon: isSubmitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: const Text(
              'Sign In',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 11),
          Text(
            errorText!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppConfig.lossColor, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          title: const Text(
            'More sign-in options',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppConfig.textSecondaryColor),
          ),
          children: [
            if (AppConfig.googleClientId.isNotEmpty)
              OutlinedButton.icon(
                onPressed: isSubmitting ? null : _googleLogin,
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Continue with Google'),
                style: _outlineStyle(),
              ),
            OutlinedButton.icon(
              onPressed: isSubmitting ? null : _biometricLogin,
              icon: const Icon(Icons.fingerprint_rounded),
              label: const Text('Continue with Biometrics'),
              style: _outlineStyle(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              "Don't have an account?",
              style: TextStyle(color: Color(0xFF6F7E92)),
            ),
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const RegisterPage(),
                      ),
                    ),
              child: const Text('Create Account'),
            ),
          ],
        ),
      ],
    ),
  );

  InputDecoration _input(String label, String hint, IconData icon) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF263650)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xFFDDE4EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(
            color: AppConfig.primaryColor,
            width: 1.5,
          ),
        ),
      );

  ButtonStyle _outlineStyle() => OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF263650),
    side: const BorderSide(color: Color(0xFFDDE4EF)),
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
  );

  Widget _legal() => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const Icon(
        Icons.verified_user_outlined,
        color: Color(0xFF7A899E),
        size: 16,
      ),
      const SizedBox(width: 5),
      const Text(
        'Secure platform',
        style: TextStyle(color: Color(0xFF7A899E), fontSize: 11),
      ),
      const Text('  |  ', style: TextStyle(color: Color(0xFF9AA6B7))),
      TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const LegalPage(title: 'Privacy Policy'),
          ),
        ),
        child: const Text('Privacy Policy'),
      ),
      const Text('|', style: TextStyle(color: Color(0xFF9AA6B7))),
      TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const LegalPage(title: 'Terms & Conditions'),
          ),
        ),
        child: const Text('Terms & Conditions'),
      ),
    ],
  );

  Future<void> _submit() async {
    final phone = phoneController.text.trim();
    final password = passwordController.text;
    if (!_isIndianMobileNumber(phone)) {
      return setState(() => errorText = 'Enter a valid Indian mobile number');
    }
    if (password.length < 8) {
      return setState(
        () => errorText = 'Password must be at least 8 characters',
      );
    }
    setState(() {
      isSubmitting = true;
      errorText = null;
    });
    try {
      final session = await authService.login(phone: phone, password: password);
      if (!mounted) return;
      MarketSocketService().connect();
      widget.onSignedIn(session);
    } catch (error) {
      if (mounted) {
        setState(
          () => errorText = clientErrorMessage(
            error,
            fallback: 'Unable to sign in. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() {
      isSubmitting = true;
      errorText = null;
    });
    try {
      final account = await googleSignIn.signIn();
      if (account == null) return;
      final token = (await account.authentication).idToken;
      if (token == null) {
        throw AuthException('Google did not return a valid identity token');
      }
      final session = await authService.googleLogin(token);
      if (!mounted) return;
      MarketSocketService().connect();
      widget.onSignedIn(session);
    } catch (error) {
      if (mounted) {
        setState(
          () => errorText = clientErrorMessage(
            error,
            fallback: 'Google sign in failed',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _biometricLogin() async {
    setState(() {
      isSubmitting = true;
      errorText = null;
    });
    try {
      final token = await authService.restoreBiometricToken();
      if (token == null) {
        throw AuthException(
          'Enable biometric quick login from your Profile first',
        );
      }
      final localAuth = LocalAuthentication();
      if (!await localAuth.isDeviceSupported()) {
        throw AuthException(
          'Biometric authentication is not available on this device',
        );
      }
      final verified = await localAuth.authenticate(
        localizedReason: 'Sign in to India Trading',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!verified) return;
      final session = await authService.biometricLogin(token);
      if (!mounted) return;
      MarketSocketService().connect();
      widget.onSignedIn(session);
    } catch (error) {
      if (mounted) {
        setState(
          () => errorText = clientErrorMessage(
            error,
            fallback: 'Biometric sign in failed',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }
}

bool _isIndianMobileNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return RegExp(r'^(91)?[6-9]\d{9}$').hasMatch(digits);
}

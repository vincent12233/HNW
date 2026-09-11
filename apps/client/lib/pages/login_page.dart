import '../l10n/app_language.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_config.dart';
import '../models/auth_session.dart';
import '../services/auth_service.dart';
import '../services/device_biometrics.dart';
import '../services/market_socket_service.dart';
import '../utils/client_error_message.dart';
import '../widgets/international_phone_field.dart';
import '../widgets/onboarding_widgets.dart';
import 'forgot_password_page.dart';
import 'kyc_upload_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onSignedIn});
  final ValueChanged<AuthSession> onSignedIn;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final verificationController = TextEditingController();
  bool requiresTwoFactor = false;
  final authService = AuthService();
  Country country = Country.parse('IN');
  bool obscure = true, busy = false, remember = false;
  DeviceBiometric? biometric;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final capability = await DeviceBiometrics.available();
    if (!mounted) return;
    setState(() {
      biometric = capability;
      remember = preferences.getBool('remember_phone') ?? false;
      if (remember) {
        phoneController.text = preferences.getString('login_phone') ?? '';
        country = Country.parse(preferences.getString('login_country') ?? 'IN');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      DeviceBiometrics.available().then((value) {
        if (mounted) setState(() => biometric = value);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    phoneController.dispose();
    passwordController.dispose();
    verificationController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<AuthSession> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final session = await action();
      if (!mounted) return;
      MarketSocketService().connect();
      widget.onSignedIn(session);
    } on TwoFactorRequiredException {
      if (mounted) setState(() => requiresTwoFactor = true);
    } on KycRequiredException catch (e) {
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => KycUploadPage(accessToken: e.token),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = clientErrorMessage(
            e,
            fallback: 'Unable to sign in. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submit() async {
    final phone = internationalPhone(phoneController.text, country.countryCode);
    if (phone == null) {
      setState(() => error = 'Enter a valid mobile number');
      return;
    }
    if (passwordController.text.length < 8) {
      setState(() => error = 'Password must be at least 8 characters');
      return;
    }
    await _run(() async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('remember_phone', remember);
      if (remember) {
        await preferences.setString('login_phone', phoneController.text.trim());
        await preferences.setString('login_country', country.countryCode);
      } else {
        await preferences.remove('login_phone');
        await preferences.remove('login_country');
      }
      return authService.login(
        phone: phone,
        password: passwordController.text,
        verificationCode: verificationController.text.trim(),
      );
    });
  }

  Future<void> _biometric() async {
    if (busy) return;
    final capability = await DeviceBiometrics.available();
    if (capability == null) {
      if (mounted) setState(() => biometric = null);
      return;
    }
    await _run(() async {
      final token = await authService.restoreBiometricToken();
      if (token == null) {
        throw const AuthException(
          'Sign in and enable quick login in Profile first.',
        );
      }
      final verified = await LocalAuthentication().authenticate(
        localizedReason: 'Sign in to your account',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!verified) throw const AuthException('Authentication cancelled');
      return authService.biometricLogin(token);
    });
  }

  Future<void> _google() => _run(() async {
    final google = GoogleSignIn(
      scopes: const ['email'],
      serverClientId: AppConfig.googleClientId,
    );
    final account = await google.signIn();
    final token = (await account?.authentication)?.idToken;
    if (token == null) throw const AuthException('Google sign in cancelled');
    return authService.googleLogin(token);
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 34),
                      const FinvestWordmark(),
                      const SizedBox(height: 44),
                      const AppText(
                        'Welcome Back!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const AppText(
                        'Login to continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppConfig.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 28),
                      InternationalPhoneField(
                        controller: phoneController,
                        country: country,
                        enabled: !busy,
                        onCountryChanged: (value) =>
                            setState(() => country = value),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: obscure,
                        enabled: !busy,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        decoration: onboardingInput('Password').copyWith(
                          suffixIcon: IconButton(
                            tooltip: obscure
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      if (requiresTwoFactor) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: verificationController,
                          enabled: !busy,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          onSubmitted: (_) => _submit(),
                          decoration: onboardingInput(
                            tr('Authenticator or recovery code'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Checkbox(
                              value: remember,
                              onChanged: busy
                                  ? null
                                  : (value) => setState(
                                      () => remember = value ?? false,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const AppText(
                            'Remember Me',
                            style: TextStyle(fontSize: 11),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const ForgotPasswordPage(),
                                    ),
                                  ),
                            child: const AppText(
                              'Forgot Password?',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: busy ? null : _submit,
                        child: busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const AppText('Sign In'),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: AppText(
                            error!,
                            style: const TextStyle(
                              color: AppConfig.lossColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Flexible(
                            child: AppText(
                              "Don't have an account?",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppConfig.textSecondaryColor,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const RegisterPage(),
                                    ),
                                  ),
                            child: const AppText(
                              'Create Account',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      if (biometric != null)
                        OutlinedButton.icon(
                          onPressed: busy ? null : _biometric,
                          icon: Icon(
                            biometric == DeviceBiometric.face
                                ? Icons.face
                                : Icons.fingerprint,
                          ),
                          label: AppText(
                            biometric == DeviceBiometric.face
                                ? 'Login with Face ID'
                                : 'Login with Fingerprint',
                          ),
                        ),
                      if (AppConfig.googleClientId.isNotEmpty)
                        TextButton(
                          onPressed: busy ? null : _google,
                          child: const AppText('Continue with Google'),
                        ),
                      const Spacer(),
                      const SizedBox(height: 40),
                      const SecureFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

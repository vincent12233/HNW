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
import '../theme/app_colors.dart';
import '../theme/auth_layout.dart';
import '../utils/client_error_message.dart';
import '../widgets/international_phone_field.dart';
import '../widgets/onboarding_widgets.dart';
import 'forgot_password_page.dart';
import 'kyc_upload_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onSignedIn, this.notice});
  final ValueChanged<AuthSession> onSignedIn;
  final String? notice;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final verificationController = TextEditingController();
  final passwordFocus = FocusNode();
  final verificationFocus = FocusNode();
  bool requiresTwoFactor = false;
  final authService = AuthService();
  Country country = Country.parse('IN');
  bool obscure = true, busy = false, remember = false;
  DeviceBiometric? biometric;
  String? formError;
  String? phoneError;
  String? passwordError;
  String? verificationError;

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
    passwordFocus.dispose();
    verificationFocus.dispose();
    super.dispose();
  }

  void _clearErrors() {
    formError = null;
    phoneError = null;
    passwordError = null;
    verificationError = null;
  }

  Future<void> _run(Future<AuthSession> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      _clearErrors();
    });
    try {
      final session = await action();
      if (!mounted) return;
      passwordController.clear();
      verificationController.clear();
      MarketSocketService().connect();
      widget.onSignedIn(session);
    } on TwoFactorRequiredException {
      if (mounted) {
        setState(() {
          requiresTwoFactor = true;
          verificationError =
              'Enter the authenticator code or a recovery code issued for this account.';
        });
        verificationFocus.requestFocus();
      }
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
          () => formError = clientErrorMessage(
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
    if (busy) return;
    final phone = internationalPhone(phoneController.text, country.countryCode);
    String? nextPhoneError;
    String? nextPasswordError;
    String? nextVerificationError;
    if (phone == null) {
      nextPhoneError = 'Enter a valid Indian mobile number';
    }
    if (passwordController.text.length < 8) {
      nextPasswordError = 'Password must be at least 8 characters';
    }
    if (requiresTwoFactor && verificationController.text.trim().isEmpty) {
      nextVerificationError = 'Enter an authenticator or recovery code';
    }
    if (nextPhoneError != null ||
        nextPasswordError != null ||
        nextVerificationError != null) {
      setState(() {
        _clearErrors();
        phoneError = nextPhoneError;
        passwordError = nextPasswordError;
        verificationError = nextVerificationError;
      });
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
        phone: phone!,
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
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (!verified) throw const AuthException('Authentication cancelled');
      return authService.biometricLogin(token);
    });
  }

  static Future<void>? _googleSignInReady;

  Future<void> _ensureGoogleSignIn() {
    return _googleSignInReady ??= GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleClientId,
    );
  }

  Future<void> _google() => _run(() async {
    await _ensureGoogleSignIn();
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: const ['email'],
    );
    final token = account.authentication.idToken;
    if (token == null) throw const AuthException('Google sign in cancelled');
    return authService.googleLogin(token);
  });

  @override
  Widget build(BuildContext context) => AuthPageScaffold(
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AuthBrandHeader(),
          const SizedBox(height: AuthLayout.sectionGap),
          const Text('Welcome Back!', style: AuthLayout.title),
          const SizedBox(height: AuthLayout.titleGap),
          const AppText('Login to continue', style: AuthLayout.subtitle),
          const SizedBox(height: 24),
          if (widget.notice != null && widget.notice!.isNotEmpty)
            AuthNoticeBanner(message: widget.notice!),
          InternationalPhoneField(
            controller: phoneController,
            country: country,
            enabled: !busy,
            lockCountry: true,
            errorText: phoneError,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => passwordFocus.requestFocus(),
            onCountryChanged: (value) => setState(() => country = value),
          ),
          const SizedBox(height: AuthLayout.fieldGap),
          TextField(
            controller: passwordController,
            focusNode: passwordFocus,
            obscureText: obscure,
            enabled: !busy,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            textInputAction: requiresTwoFactor
                ? TextInputAction.next
                : TextInputAction.done,
            onSubmitted: (_) {
              if (requiresTwoFactor) {
                verificationFocus.requestFocus();
              } else {
                _submit();
              }
            },
            decoration: onboardingInput(
              'Password',
              errorText: passwordError,
            ).copyWith(
              suffixIcon: IconButton(
                tooltip: obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  semanticLabel: obscure ? 'Show password' : 'Hide password',
                ),
              ),
            ),
          ),
          if (requiresTwoFactor) ...[
            const SizedBox(height: 16),
            TextField(
              controller: verificationController,
              focusNode: verificationFocus,
              enabled: !busy,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: onboardingInput(
                'Authenticator or recovery code',
                errorText: verificationError,
                helperText:
                    'Use the authenticator app or a support-issued recovery code. No SMS code is sent.',
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    child: Checkbox(
                      value: remember,
                      onChanged: busy
                          ? null
                          : (value) => setState(() => remember = value ?? false),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const AppText(
                    'Remember Me',
                    style: TextStyle(fontSize: 13, letterSpacing: 0),
                  ),
                ],
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ForgotPasswordPage(),
                        ),
                      ),
                child: const AppText(
                  'Forgot Password?',
                  style: TextStyle(fontSize: 13, letterSpacing: 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (formError != null) AuthFormError(message: formError!),
          AuthSubmitButton(
            label: 'Login',
            busy: busy,
            onPressed: _submit,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Flexible(
                child: AppText(
                  "Don't have an account?",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 0,
                    color: AppColors.textSecondary,
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
                  style: TextStyle(fontSize: 13, letterSpacing: 0),
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
          const SecureFooter(),
        ],
      ),
    ),
  );
}

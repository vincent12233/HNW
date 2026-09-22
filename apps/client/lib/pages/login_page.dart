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
import '../theme/app_motion.dart';
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
  final verificationFieldKey = GlobalKey();
  bool requiresTwoFactor = false;
  final authService = AuthService();
  Country country = Country.parse('IN');
  bool obscure = true, busy = false, remember = false, succeeded = false;
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
    if (busy || succeeded) return;
    setState(() {
      busy = true;
      succeeded = false;
      _clearErrors();
    });
    try {
      final session = await action();
      if (!mounted) return;
      passwordController.clear();
      verificationController.clear();
      setState(() => succeeded = true);
      await authSuccessPause(context);
      if (!mounted) return;
      MarketSocketService().connect();
      widget.onSignedIn(session);
    } on TwoFactorRequiredException {
      if (mounted) {
        setState(() {
          succeeded = false;
          requiresTwoFactor = true;
          verificationError =
              'Enter the authenticator code or a recovery code issued for this account.';
        });
        verificationFocus.requestFocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = verificationFieldKey.currentContext;
          if (target == null) return;
          Scrollable.ensureVisible(
            target,
            duration: AppMotion.duration(target, AppMotion.state),
            curve: AppMotion.ease,
            alignment: 0.2,
          );
        });
      }
    } on KycRequiredException catch (e) {
      if (!mounted) return;
      setState(() => succeeded = true);
      await authSuccessPause(context);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => KycUploadPage(accessToken: e.token),
        ),
      );
      if (mounted) {
        setState(() {
          busy = false;
          succeeded = false;
        });
      }
    } catch (e) {
      if (mounted) {
        passwordController.clear();
        setState(() {
          succeeded = false;
          formError = clientErrorMessage(
            e,
            fallback: 'Unable to sign in. Please try again.',
          );
        });
      }
    } finally {
      if (mounted && !succeeded) setState(() => busy = false);
    }
  }

  Future<void> _submit() async {
    if (busy || succeeded) return;
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
    if (busy || succeeded) return;
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
  Widget build(BuildContext context) {
    final skipEntrance = widget.notice != null && widget.notice!.isNotEmpty;
    return AuthPageScaffold(
      child: AppEntranceScope(
        play: !skipEntrance,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppEntrance(
                delay: const Duration(milliseconds: 80),
                offsetY: 8,
                child: const AnimatedAuthBrandHeader(),
              ),
              const SizedBox(height: AuthLayout.sectionGap),
              AppEntrance(
                delay: const Duration(milliseconds: 140),
                offsetY: 10,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Welcome Back!', style: AuthLayout.title),
                    SizedBox(height: AuthLayout.titleGap),
                    AppText('Login to continue', style: AuthLayout.subtitle),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (widget.notice != null && widget.notice!.isNotEmpty)
                AuthNoticeBanner(message: widget.notice!),
              AppEntrance(
                delay: const Duration(milliseconds: 220),
                offsetY: 12,
                child: AuthFocusGlow(
                  child: AuthErrorShake(
                    errorText: phoneError,
                    child: InternationalPhoneField(
                      controller: phoneController,
                      country: country,
                      enabled: !busy && !succeeded,
                      errorText: phoneError,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => passwordFocus.requestFocus(),
                      onCountryChanged: (value) =>
                          setState(() => country = value),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AuthLayout.fieldGap),
              AppEntrance(
                delay: const Duration(milliseconds: 280),
                offsetY: 12,
                child: AuthFocusGlow(
                  child: AuthErrorShake(
                    errorText: passwordError,
                    child: TextField(
                      controller: passwordController,
                      focusNode: passwordFocus,
                      obscureText: obscure,
                      enabled: !busy && !succeeded,
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
                      decoration:
                          onboardingInput(
                            'Password',
                            errorText: passwordError,
                          ).copyWith(
                            suffixIcon: AuthPasswordToggle(
                              obscure: obscure,
                              onPressed: () =>
                                  setState(() => obscure = !obscure),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
              if (requiresTwoFactor)
                Padding(
                  key: verificationFieldKey,
                  padding: const EdgeInsets.only(top: 16),
                  child: AuthFocusGlow(
                    child: AuthErrorShake(
                      errorText: verificationError,
                      child: TextField(
                        controller: verificationController,
                        focusNode: verificationFocus,
                        enabled: !busy && !succeeded,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: onboardingInput(
                          'Authenticator or recovery code',
                          errorText: verificationError,
                          helperText:
                              'Use the authenticator app or a support-issued recovery code.',
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              AppEntrance(
                delay: const Duration(milliseconds: 340),
                offsetY: 0,
                child: Wrap(
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
                            onChanged: busy || succeeded
                                ? null
                                : (value) =>
                                      setState(() => remember = value ?? false),
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
                      onPressed: busy || succeeded
                          ? null
                          : () => Navigator.push(
                              context,
                              AuthSlidePageRoute<void>(
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
              ),
              const SizedBox(height: 12),
              AppEntrance(
                delay: const Duration(milliseconds: 400),
                offsetY: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (formError != null) AuthFormError(message: formError!),
                    AuthSubmitButton(
                      label: 'Login',
                      busy: busy,
                      succeeded: succeeded,
                      onPressed: _submit,
                    ),
                    AuthTextActionRow(
                      prompt: "Don't have an account?",
                      actionLabel: 'Create Account',
                      onPressed: busy || succeeded
                          ? null
                          : () => Navigator.push(
                              context,
                              AuthSlidePageRoute<void>(
                                builder: (_) => const RegisterPage(),
                              ),
                            ),
                    ),
                    if (biometric != null)
                      OutlinedButton.icon(
                        onPressed: busy || succeeded ? null : _biometric,
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
                        onPressed: busy || succeeded ? null : _google,
                        child: const AppText('Continue with Google'),
                      ),
                    const SecureFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

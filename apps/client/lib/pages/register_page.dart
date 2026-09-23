import '../l10n/app_language.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/auth_layout.dart';
import '../utils/client_error_message.dart';
import '../widgets/international_phone_field.dart';
import '../widgets/onboarding_widgets.dart';
import 'kyc_upload_page.dart';
import 'legal_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final phone = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController(),
      invite = TextEditingController();
  final passwordFocus = FocusNode();
  final confirmFocus = FocusNode();
  final inviteFocus = FocusNode();
  late final TapGestureRecognizer termsTap;
  late final TapGestureRecognizer privacyTap;
  Country country = Country.parse('IN');
  bool obscure = true, obscureConfirm = true, accepted = false, busy = false;
  bool continuingToKyc = false;
  bool succeeded = false;
  String? formError;
  String? phoneError;
  String? passwordError;
  String? confirmError;
  String? inviteError;

  @override
  void initState() {
    super.initState();
    termsTap = TapGestureRecognizer()
      ..onTap = () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const LegalPage(title: 'Terms & Conditions'),
          ),
        );
      };
    privacyTap = TapGestureRecognizer()
      ..onTap = () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const LegalPage(title: 'Privacy'),
          ),
        );
      };
    passwordFocus.addListener(_onPasswordFocus);
  }

  void _onPasswordFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [phone, password, confirm, invite]) {
      c.dispose();
    }
    passwordFocus
      ..removeListener(_onPasswordFocus)
      ..dispose();
    confirmFocus.dispose();
    inviteFocus.dispose();
    termsTap.dispose();
    privacyTap.dispose();
    super.dispose();
  }

  void _clearErrors() {
    formError = null;
    phoneError = null;
    passwordError = null;
    confirmError = null;
    inviteError = null;
  }

  void _mapServerError(Object error) {
    final message = clientErrorMessage(error);
    final lower = message.toLowerCase();
    if (lower.contains('invite')) {
      inviteError = message;
      return;
    }
    if (lower.contains('already') ||
        lower.contains('phone') ||
        lower.contains('mobile')) {
      phoneError = message;
      return;
    }
    if (lower.contains('password')) {
      passwordError = message;
      return;
    }
    formError = message;
  }

  Future<void> _submit() async {
    if (busy || !accepted || continuingToKyc || succeeded) return;
    final normalized = internationalPhone(phone.text, country.countryCode);
    String? nextPhoneError;
    String? nextPasswordError;
    String? nextConfirmError;
    String? nextInviteError;
    if (normalized == null) {
      nextPhoneError = 'Enter a valid Indian mobile number';
    }
    if (password.text.length < 8) {
      nextPasswordError = 'Password must be at least 8 characters';
    }
    if (confirm.text.isEmpty || password.text != confirm.text) {
      nextConfirmError = 'Passwords do not match';
    }
    final inviteCode = invite.text.trim();
    if (inviteCode.isEmpty) {
      nextInviteError = 'Invite code is required';
    } else if (inviteCode.length < 7 || inviteCode.length > 20) {
      nextInviteError = 'Enter a valid invite code';
    }
    if (nextPhoneError != null ||
        nextPasswordError != null ||
        nextConfirmError != null ||
        nextInviteError != null) {
      setState(() {
        _clearErrors();
        phoneError = nextPhoneError;
        passwordError = nextPasswordError;
        confirmError = nextConfirmError;
        inviteError = nextInviteError;
      });
      return;
    }
    setState(() {
      busy = true;
      _clearErrors();
    });
    try {
      final token = await AuthService().register(
        phone: normalized!,
        password: password.text,
        inviteCode: invite.text,
      );
      if (!mounted) return;
      password.clear();
      confirm.clear();
      setState(() {
        busy = false;
        succeeded = true;
      });
      await authSuccessPause(context);
      if (!mounted) return;
      continuingToKyc = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => KycUploadPage(accessToken: token),
        ),
      );
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          succeeded = false;
          _clearErrors();
          _mapServerError(e);
        });
      }
    } finally {
      if (mounted && !continuingToKyc && !succeeded) {
        setState(() => busy = false);
      }
    }
  }

  String? get _confirmHelper {
    if (confirm.text.isEmpty) return null;
    return password.text == confirm.text
        ? 'Passwords match'
        : 'Passwords do not match';
  }

  @override
  Widget build(BuildContext context) {
    if (continuingToKyc) {
      return const AuthPageScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthBrandHeader(),
            SizedBox(height: 32),
            AppText(
              'Continue to identity verification',
              style: AuthLayout.title,
            ),
            SizedBox(height: 8),
            AppText(
              'Your account is not active yet. Complete the existing document verification steps.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                letterSpacing: 0,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AuthPageScaffold(
      appBar: AppBar(
        backgroundColor: AuthLayout.pageBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      child: AppEntranceScope(
        total: AppMotion.entranceRegister,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AnimatedAuthBrandHeader(showSlogan: false),
              const SizedBox(height: 20),
              AppEntrance(
                delay: Duration.zero,
                offsetY: 10,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppText(
                      'Create Account',
                      style: AuthLayout.title,
                      softWrap: true,
                    ),
                    SizedBox(height: AuthLayout.titleGap),
                    AppText(
                      'Register with an Indian mobile number, password, and invite code.',
                      style: AuthLayout.subtitle,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppEntrance(
                delay: const Duration(milliseconds: 80),
                offsetY: 8,
                child: const VerificationBanner(
                  title: 'Invite Code is Mandatory',
                  subtitle:
                      'A valid invite code is required to create an account.',
                  icon: Icons.card_giftcard,
                ),
              ),
              const SizedBox(height: 20),
              AppEntrance(
                delay: const Duration(milliseconds: 140),
                offsetY: 12,
                child: AuthFocusGlow(
                  child: AuthErrorShake(
                    errorText: phoneError,
                    child: InternationalPhoneField(
                      controller: phone,
                      country: country,
                      enabled: !busy && !succeeded,
                      errorText: phoneError,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => passwordFocus.requestFocus(),
                      onCountryChanged: (v) => setState(() => country = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppEntrance(
                delay: const Duration(milliseconds: 200),
                offsetY: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthFocusGlow(
                      child: AuthErrorShake(
                        errorText: passwordError,
                        child: TextField(
                          controller: password,
                          focusNode: passwordFocus,
                          enabled: !busy && !succeeded,
                          obscureText: obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => confirmFocus.requestFocus(),
                          onChanged: (_) => setState(() {}),
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
                    if (passwordFocus.hasFocus || password.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 2),
                        child: Row(
                          children: [
                            Icon(
                              password.text.length >= 8
                                  ? Icons.check_circle_outline
                                  : Icons.radio_button_unchecked,
                              size: 16,
                              color: AppColors.textSecondary,
                              semanticLabel: password.text.length >= 8
                                  ? 'Password has at least 8 characters'
                                  : 'Password needs at least 8 characters',
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: AppText(
                                'At least 8 characters',
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 0,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppEntrance(
                delay: const Duration(milliseconds: 260),
                offsetY: 12,
                child: AuthFocusGlow(
                  child: AuthErrorShake(
                    errorText: confirmError,
                    child: TextField(
                      controller: confirm,
                      focusNode: confirmFocus,
                      enabled: !busy && !succeeded,
                      obscureText: obscureConfirm,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => inviteFocus.requestFocus(),
                      onChanged: (_) => setState(() {}),
                      decoration:
                          onboardingInput(
                            'Confirm Password',
                            errorText: confirmError,
                            helperText: _confirmHelper,
                          ).copyWith(
                            suffixIconConstraints: const BoxConstraints(
                              minHeight: AppMotion.tapTarget,
                              minWidth: AppMotion.tapTarget,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (confirm.text.isNotEmpty &&
                                    password.text == confirm.text)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.check_circle_outline,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                      semanticLabel: tr('Passwords match'),
                                    ),
                                  ),
                                AuthPasswordToggle(
                                  obscure: obscureConfirm,
                                  onPressed: () => setState(
                                    () => obscureConfirm = !obscureConfirm,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppEntrance(
                delay: const Duration(milliseconds: 320),
                offsetY: 12,
                child: AuthFocusGlow(
                  child: AuthErrorShake(
                    errorText: inviteError,
                    child: TextField(
                      controller: invite,
                      focusNode: inviteFocus,
                      enabled: !busy && !succeeded,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration:
                          onboardingInput(
                            'Invite Code',
                            errorText: inviteError,
                            helperText: 'Required. 7 to 20 characters.',
                          ).copyWith(
                            suffixIcon: const Icon(
                              Icons.card_giftcard,
                              size: 18,
                            ),
                          ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppEntrance(
                delay: const Duration(milliseconds: 380),
                offsetY: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Checkbox(
                        value: accepted,
                        onChanged: busy || succeeded
                            ? null
                            : (v) => setState(() => accepted = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 13,
                            letterSpacing: 0,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(text: '${tr('I agree to the')} '),
                            TextSpan(
                              text: tr('Terms & Conditions'),
                              style: const TextStyle(
                                color: AppColors.brandPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              recognizer: termsTap,
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: tr('Privacy'),
                              style: const TextStyle(
                                color: AppColors.brandPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              recognizer: privacyTap,
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppEntrance(
                delay: const Duration(milliseconds: 440),
                offsetY: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (formError != null) AuthFormError(message: formError!),
                    AuthSubmitButton(
                      label: 'Sign Up',
                      busy: busy,
                      succeeded: succeeded,
                      enabled: accepted,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 8),
                    AuthTextActionRow(
                      prompt: 'Already have an account?',
                      actionLabel: 'Login',
                      onPressed: busy || succeeded
                          ? null
                          : () => Navigator.pop(context),
                    ),
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

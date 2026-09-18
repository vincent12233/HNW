import '../l10n/app_language.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
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
  }

  @override
  void dispose() {
    for (final c in [phone, password, confirm, invite]) {
      c.dispose();
    }
    passwordFocus.dispose();
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
    if (busy || !accepted || continuingToKyc) return;
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
        continuingToKyc = true;
      });
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => KycUploadPage(accessToken: token),
        ),
      );
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _clearErrors();
          _mapServerError(e);
        });
      }
    } finally {
      if (mounted && !continuingToKyc) setState(() => busy = false);
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
            Text(
              'Continue to identity verification',
              style: AuthLayout.title,
            ),
            SizedBox(height: 8),
            AppText(
              'Your account is not active yet. Complete the existing document verification steps. No SMS or email code is sent.',
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
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Create Account', style: AuthLayout.title),
            const SizedBox(height: AuthLayout.titleGap),
            const AppText(
              'Register with an Indian mobile number, password, and invite code.',
              style: AuthLayout.subtitle,
            ),
            const SizedBox(height: 20),
              const VerificationBanner(
                title: 'Invite Code is Mandatory',
                subtitle:
                    'You need a valid invite code to create an account. No SMS or email verification is sent.',
                icon: Icons.card_giftcard,
              ),
              const SizedBox(height: 20),
              InternationalPhoneField(
                controller: phone,
                country: country,
                enabled: !busy,
                lockCountry: true,
                errorText: phoneError,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => passwordFocus.requestFocus(),
                onCountryChanged: (v) => setState(() => country = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                focusNode: passwordFocus,
                enabled: !busy,
                obscureText: obscure,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => confirmFocus.requestFocus(),
                onChanged: (_) => setState(() {}),
                decoration: onboardingInput(
                  'Password',
                  errorText: passwordError,
                  helperText: 'Use at least 8 characters.',
                ).copyWith(
                  suffixIcon: IconButton(
                    tooltip: obscure ? 'Show password' : 'Hide password',
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      semanticLabel: obscure ? 'Show password' : 'Hide password',
                    ),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirm,
                focusNode: confirmFocus,
                enabled: !busy,
                obscureText: obscureConfirm,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => inviteFocus.requestFocus(),
                onChanged: (_) => setState(() {}),
                decoration: onboardingInput(
                  'Confirm Password',
                  errorText: confirmError,
                  helperText: _confirmHelper,
                ).copyWith(
                  suffixIcon: IconButton(
                    tooltip: obscureConfirm
                        ? 'Show password'
                        : 'Hide password',
                    icon: Icon(
                      obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      semanticLabel: obscureConfirm
                          ? 'Show password'
                          : 'Hide password',
                    ),
                    onPressed: () =>
                        setState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: invite,
                focusNode: inviteFocus,
                enabled: !busy,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: onboardingInput(
                  'Invite Code',
                  errorText: inviteError,
                  helperText: 'Required. 7 to 20 characters.',
                ).copyWith(suffixIcon: const Icon(Icons.card_giftcard, size: 18)),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Checkbox(
                      value: accepted,
                      onChanged: busy
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
              const SizedBox(height: 12),
              if (formError != null) AuthFormError(message: formError!),
              AuthSubmitButton(
                label: 'Sign Up',
                busy: busy,
                enabled: accepted,
                onPressed: _submit,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Flexible(
                    child: AppText(
                      'Already have an account?',
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 0,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: const AppText(
                      'Login',
                      style: TextStyle(fontSize: 13, letterSpacing: 0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
    );
  }
}

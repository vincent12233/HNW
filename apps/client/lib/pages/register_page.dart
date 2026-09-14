import '../l10n/app_language.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import '../app_config.dart';
import '../services/auth_service.dart';
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
  Country country = Country.parse('IN');
  bool obscure = true, obscureConfirm = true, accepted = false, busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in [phone, password, confirm, invite]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (busy || !accepted) return;
    final normalized = internationalPhone(phone.text, country.countryCode);
    if (normalized == null) {
      setState(() => error = 'Enter a valid mobile number');
      return;
    }
    if (password.text.length < 8) {
      setState(() => error = 'Password must be at least 8 characters');
      return;
    }
    if (password.text != confirm.text) {
      setState(() => error = 'Passwords do not match');
      return;
    }
    if (invite.text.trim().length < 7 || invite.text.trim().length > 20) {
      setState(() => error = 'Enter a valid invite code');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final token = await AuthService().register(
        phone: normalized,
        password: password.text,
        inviteCode: invite.text,
      );
      if (!mounted) return;
      // Release the form before changing routes. Awaiting a replacement route
      // can keep Flutter Web's hash-router transition in a busy state.
      setState(() => busy = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => KycUploadPage(accessToken: token),
        ),
      );
      return;
    } catch (e) {
      if (mounted) setState(() => error = clientErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const AppText(
              'Create Account',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const AppText(
              'Join Finvest and start your investing journey',
              style: TextStyle(
                fontSize: 12,
                color: AppConfig.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const VerificationBanner(
              title: 'Invite Code is Mandatory',
              subtitle: 'You need an invite code to create an account',
              icon: Icons.card_giftcard,
            ),
            const SizedBox(height: 24),
            InternationalPhoneField(
              controller: phone,
              country: country,
              enabled: !busy,
              onCountryChanged: (v) => setState(() => country = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: password,
              enabled: !busy,
              obscureText: obscure,
              autofillHints: const [AutofillHints.newPassword],
              decoration: onboardingInput('Password').copyWith(
                suffixIcon: IconButton(
                  tooltip: 'Show password',
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirm,
              enabled: !busy,
              obscureText: obscureConfirm,
              decoration: onboardingInput('Confirm Password').copyWith(
                suffixIcon: IconButton(
                  tooltip: 'Show password',
                  icon: Icon(
                    obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => obscureConfirm = !obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: invite,
              enabled: !busy,
              textCapitalization: TextCapitalization.characters,
              decoration: onboardingInput(
                'Invite Code',
              ).copyWith(suffixIcon: const Icon(Icons.card_giftcard, size: 18)),
            ),
            const SizedBox(height: 18),
            Row(
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
                const SizedBox(width: 6),
                const Flexible(
                  child: AppText(
                    'I agree to the',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                Flexible(
                  flex: 2,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const LegalPage(title: 'Terms & Conditions'),
                      ),
                    ),
                    child: const AppText(
                      'Terms & Conditions',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy || !accepted ? null : _submit,
              child: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const AppText('Sign Up'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AppText(
                  error!,
                  style: const TextStyle(color: AppConfig.lossColor),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Flexible(
                  child: AppText(
                    'Already have an account?',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppConfig.textSecondaryColor,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: const AppText('Login', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

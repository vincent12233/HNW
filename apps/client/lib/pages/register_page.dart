import '../l10n/app_language.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/auth_layout.dart';
import '../utils/client_error_message.dart';
import '../widgets/international_phone_field.dart';
import '../widgets/onboarding_widgets.dart';
import 'kyc_upload_page.dart';
import 'legal_page.dart';

part 'register_page_content.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  void _setState(VoidCallback fn) => setState(fn);
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
  Widget build(BuildContext context) => _buildContent(context);

}

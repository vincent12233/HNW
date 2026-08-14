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
    backgroundColor: const Color(0xFFF7FAFF),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              wide ? 36 : 20,
              22,
              wide ? 36 : 20,
              24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: Column(
                  children: [
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _hero(height: 590)),
                          const SizedBox(width: 34),
                          SizedBox(width: 455, child: _loginCard()),
                        ],
                      )
                    else ...[
                      _hero(height: constraints.maxWidth < 380 ? 310 : 345),
                      const SizedBox(height: 14),
                      _loginCard(),
                    ],
                    const SizedBox(height: 16),
                    _benefits(wide),
                    const SizedBox(height: 11),
                    _legal(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _hero({required double height}) => SizedBox(
    height: height,
    child: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: const _LoginHeroPainter())),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppBrandLogo(size: 58),
                  const SizedBox(width: 13),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'India Trading',
                        style: TextStyle(
                          color: Color(0xFF0A1730),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Smart Investing, Better Future',
                        style: TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(flex: 2),
              const Text(
                'Invest Smarter,',
                style: TextStyle(
                  color: Color(0xFF0A1730),
                  fontSize: 34,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.7,
                ),
              ),
              const Text(
                'Grow Better',
                style: TextStyle(
                  color: Color(0xFF156EF6),
                  fontSize: 34,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 18),
              const SizedBox(
                width: 330,
                child: Text(
                  'A focused platform for Inst., OTC and IPO opportunities with live market insights.',
                  style: TextStyle(
                    color: Color(0xFF5F6F86),
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              const Wrap(
                spacing: 18,
                runSpacing: 9,
                children: [
                  _HeroTag(Icons.shield_outlined, 'Secure'),
                  _HeroTag(Icons.bolt_rounded, 'Fast'),
                  _HeroTag(Icons.pie_chart_outline_rounded, 'Reliable'),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _loginCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(26, 25, 26, 23),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE9EEF7)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x140E4E9C),
          blurRadius: 28,
          offset: Offset(0, 12),
        ),
      ],
    ),
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
              backgroundColor: const Color(0xFF146EF5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
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
        const SizedBox(height: 15),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('or', style: TextStyle(color: Color(0xFF8894A6))),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 13),
        OutlinedButton.icon(
          onPressed: isSubmitting ? null : _googleLogin,
          icon: const Text(
            'G',
            style: TextStyle(
              color: Color(0xFF4285F4),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          label: const Text('Continue with Google'),
          style: _outlineStyle(),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: isSubmitting ? null : _biometricLogin,
          icon: const Icon(Icons.fingerprint_rounded),
          label: const Text('Continue with Biometrics'),
          style: _outlineStyle(),
        ),
        const SizedBox(height: 12),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDDE4EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
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
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
  );

  Widget _benefits(bool wide) {
    const values = [
      (
        Icons.shield_outlined,
        Color(0xFF0F72EA),
        Color(0xFFE9F3FF),
        'Bank-level Security',
        'Protected account access',
      ),
      (
        Icons.bolt_rounded,
        Color(0xFF17A868),
        Color(0xFFE9F9EF),
        'Quick & Easy',
        'Streamlined onboarding',
      ),
      (
        Icons.trending_up_rounded,
        Color(0xFF6B57E8),
        Color(0xFFF1EDFF),
        'Real-time Data',
        'Live market updates',
      ),
      (
        Icons.support_agent_rounded,
        Color(0xFFF08A28),
        Color(0xFFFFF1E5),
        'Online Support',
        'Help when you need it',
      ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0D21518C), blurRadius: 18)],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        runSpacing: 18,
        children: values
            .map(
              (value) => SizedBox(
                width: wide ? 245 : 165,
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: value.$3,
                      child: Icon(value.$1, color: value.$2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value.$4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF18253D),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value.$5,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF8290A4),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

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

class _HeroTag extends StatelessWidget {
  const _HeroTag(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 15,
        backgroundColor: const Color(0xFFEAF3FF),
        child: Icon(icon, size: 16, color: const Color(0xFF1571EC)),
      ),
      const SizedBox(width: 7),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF263650),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _LoginHeroPainter extends CustomPainter {
  const _LoginHeroPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader =
          const RadialGradient(
            colors: [Color(0x332D86FF), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .78, size.height * .48),
              radius: size.width * .55,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);
    final candle = Paint()
      ..color = const Color(0x223D78F0)
      ..strokeWidth = 2;
    for (var i = 0; i < 6; i++) {
      final x = size.width * (.56 + i * .065);
      final y = size.height * (.36 - i * .035);
      canvas.drawLine(Offset(x, y - 14), Offset(x, y + 30), candle);
      canvas.drawRect(Rect.fromLTWH(x - 6, y, 12, 20), candle);
    }
    final bars = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFF1531B9), Color(0xFF39A8F8)],
      ).createShader(Offset.zero & size);
    for (var i = 0; i < 5; i++) {
      final height = 35.0 + i * 25;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width - 145 + i * 27,
            size.height - 68 - height,
            18,
            height,
          ),
          const Radius.circular(3),
        ),
        bars,
      );
    }
    final growth = Path()
      ..moveTo(size.width * .57, size.height * .76)
      ..lineTo(size.width * .69, size.height * .65)
      ..lineTo(size.width * .79, size.height * .69)
      ..lineTo(size.width * .92, size.height * .43);
    canvas.drawPath(
      growth,
      Paint()
        ..color = const Color(0xFF18B98A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawLine(
      Offset(size.width * .92, size.height * .43),
      Offset(size.width * .89, size.height * .47),
      Paint()
        ..color = const Color(0xFF18B98A)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(size.width * .92, size.height * .43),
      Offset(size.width * .91, size.height * .49),
      Paint()
        ..color = const Color(0xFF18B98A)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    final skyline = Paint()..color = const Color(0x111C75D8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .61,
          size.height * .49,
          size.width * .22,
          size.height * .25,
        ),
        const Radius.circular(70),
      ),
      skyline,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

bool _isIndianMobileNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return RegExp(r'^(91)?[6-9]\d{9}$').hasMatch(digits);
}

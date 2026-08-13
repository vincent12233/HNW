import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';

import '../app_config.dart';
import '../models/auth_session.dart';
import '../services/auth_service.dart';
import '../services/market_socket_service.dart';
import '../utils/client_error_message.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050D18),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _FintechBackgroundPainter()),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 850;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 40 : 20,
                    vertical: 22,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Column(
                        children: [
                          _brand(),
                          const SizedBox(height: 28),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: _hero()),
                                const SizedBox(width: 48),
                                SizedBox(width: 440, child: _loginCard()),
                              ],
                            )
                          else ...[
                            _hero(),
                            const SizedBox(height: 26),
                            _loginCard(),
                          ],
                          const SizedBox(height: 18),
                          _benefits(wide),
                          const SizedBox(height: 18),
                          _legal(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _brand() => Row(
    children: [
      Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1187FF), Color(0xFF5747FF)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x552A74FF), blurRadius: 22),
          ],
        ),
        child: const Icon(
          Icons.candlestick_chart_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
      const SizedBox(width: 13),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'India Trading',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Smart Investing, Better Future',
            style: TextStyle(color: Color(0xFF8292AA), fontSize: 13),
          ),
        ],
      ),
    ],
  );

  Widget _hero() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Invest Smarter,\nGrow Better',
        style: TextStyle(
          color: Colors.white,
          fontSize: 39,
          height: 1.08,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'A focused platform for Stocks, Inst., IPO and OTC trading.',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16, height: 1.5),
      ),
      const SizedBox(height: 22),
      Wrap(
        spacing: 18,
        runSpacing: 10,
        children: [
          _heroTag(Icons.shield_outlined, 'Secure'),
          _heroTag(Icons.bolt_rounded, 'Fast'),
          _heroTag(Icons.pie_chart_outline, 'Reliable'),
        ],
      ),
      const SizedBox(height: 22),
      SizedBox(
        height: 150,
        child: CustomPaint(
          painter: _GrowthChartPainter(),
          size: const Size(double.infinity, 150),
        ),
      ),
    ],
  );
  Widget _heroTag(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFF152B44),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF39A0FF), size: 17),
      ),
      const SizedBox(width: 7),
      Text(
        text,
        style: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _loginCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
    decoration: BoxDecoration(
      color: const Color(0xD9112034),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 35,
          offset: Offset(0, 16),
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
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sign in to continue',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF91A0B5)),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
          decoration: _input('Mobile Number', Icons.phone_outlined).copyWith(
            prefixText: '+91  ',
            prefixStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          style: const TextStyle(color: Colors.white),
          decoration: _input('Password', Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => obscurePassword = !obscurePassword),
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF9CACBF),
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
          height: 54,
          child: FilledButton(
            onPressed: isSubmitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF087BFF), Color(0xFF5942FF)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: isSubmitting
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(Icons.arrow_forward_rounded),
                        ],
                      ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 11),
          Text(
            errorText!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ],
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(child: Divider(color: Colors.white12)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('or', style: TextStyle(color: Color(0xFF8190A5))),
            ),
            Expanded(child: Divider(color: Colors.white12)),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: isSubmitting ? null : _googleLogin,
          icon: const Text(
            'G',
            style: TextStyle(
              color: Color(0xFF91A0B5),
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
          label: const Text('Continue with Face ID / Biometrics'),
          style: _outlineStyle(),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Don't have an account?",
              style: TextStyle(color: Color(0xFF91A0B5)),
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
  InputDecoration _input(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF8292A8)),
    prefixIcon: Icon(icon, color: const Color(0xFF91A0B5)),
    filled: true,
    fillColor: Colors.white.withValues(alpha: .055),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Colors.white12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: AppConfig.primaryColor, width: 1.4),
    ),
  );
  ButtonStyle _outlineStyle() => OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF91A0B5),
    side: const BorderSide(color: Colors.white12),
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  );

  Widget _benefits(bool wide) {
    final values = [
      (
        Icons.shield_outlined,
        'Bank-level Security',
        'Protected account access',
      ),
      (Icons.bolt_rounded, 'Quick & Easy', 'Streamlined onboarding'),
      (Icons.show_chart_rounded, 'Real-time Data', 'Live market updates'),
      (Icons.support_agent_rounded, '24/7 Support', 'Online customer service'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x99112034),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: wide ? 30 : 9,
        runSpacing: 14,
        children: values
            .map(
              (v) => SizedBox(
                width: wide ? 210 : 155,
                child: Column(
                  children: [
                    Icon(v.$1, color: const Color(0xFF44A5FF)),
                    const SizedBox(height: 7),
                    Text(
                      v.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v.$3,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF7F90A5),
                        fontSize: 11,
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
        color: Color(0xFF71839A),
        size: 16,
      ),
      const SizedBox(width: 5),
      const Text(
        'Secure trading platform',
        style: TextStyle(color: Color(0xFF71839A), fontSize: 12),
      ),
      const Text('  |  ', style: TextStyle(color: Color(0xFF526277))),
      TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const LegalPage(title: 'Privacy Policy'),
          ),
        ),
        child: const Text('Privacy Policy'),
      ),
      const Text('|', style: TextStyle(color: Color(0xFF526277))),
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
    final phone = phoneController.text.trim(),
        password = passwordController.text;
    if (!_isIndianMobileNumber(phone)) {
      setState(() => errorText = 'Enter a valid Indian mobile number');
      return;
    }
    if (password.length < 8) {
      setState(() => errorText = 'Password must be at least 8 characters');
      return;
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
      if (!mounted) return;
      setState(
        () => errorText = clientErrorMessage(
          error,
          fallback: 'Unable to sign in. Please try again.',
        ),
      );
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
      if (token == null)
        throw AuthException('Google did not return a valid identity token');
      final session = await authService.googleLogin(token);
      if (!mounted) return;
      MarketSocketService().connect();
      widget.onSignedIn(session);
    } catch (error) {
      if (mounted)
        setState(
          () => errorText = clientErrorMessage(
            error,
            fallback: 'Google sign in failed',
          ),
        );
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
      if (token == null)
        throw AuthException(
          'Enable biometric quick login from your Profile first',
        );
      final localAuth = LocalAuthentication();
      final supported = await localAuth.isDeviceSupported();
      if (!supported)
        throw AuthException(
          'Biometric authentication is not available on this device',
        );
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
      if (mounted)
        setState(
          () => errorText = clientErrorMessage(
            error,
            fallback: 'Biometric sign in failed',
          ),
        );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }
}

class _FintechBackgroundPainter extends CustomPainter {
  const _FintechBackgroundPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF071728), Color(0xFF050B14), Color(0xFF10102A)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, p);
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [const Color(0x553B82F6), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .82, size.height * .2),
              radius: size.width * .65,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GrowthChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .05)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 5),
        Offset(size.width, size.height * i / 5),
        grid,
      );
    }
    final bars = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFF1747A7), Color(0xFF32A8FF)],
      ).createShader(Offset.zero & size);
    for (var i = 0; i < 6; i++) {
      final h = 24.0 + i * 17;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width - 170 + i * 27, size.height - h, 17, h),
          const Radius.circular(4),
        ),
        bars,
      );
    }
    final path = Path()
      ..moveTo(4, size.height - 18)
      ..lineTo(size.width * .28, size.height - 42)
      ..lineTo(size.width * .48, size.height - 34)
      ..lineTo(size.width * .69, size.height - 88)
      ..lineTo(size.width - 10, 18);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF21D6A5)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

bool _isIndianMobileNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return RegExp(r'^(91)?[6-9]\d{9}$').hasMatch(digits);
}

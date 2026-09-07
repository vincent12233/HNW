import 'dart:async';
import 'dart:convert';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart';
import '../services/auth_service.dart';
import '../utils/client_error_message.dart';
import '../widgets/international_phone_field.dart';
import '../widgets/onboarding_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}
class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final phone = TextEditingController(), message = TextEditingController(), code = TextEditingController(), password = TextEditingController(), confirm = TextEditingController();
  final storage = const FlutterSecureStorage();
  Country country = Country.parse('IN');
  String? token, error;
  bool busy = false, polling = false, ready = false, obscure = true, closed = false;
  List<Map<String, dynamic>> messages = [];
  Timer? timer;
  @override
  void initState() { super.initState(); _restore(); }
  Future<void> _restore() async {
    token = await storage.read(key: 'recovery_token');
    if (!mounted) return;
    if (token != null) { await _poll(); _startPolling(); }
    if (mounted) setState(() => ready = true);
  }
  void _startPolling() { timer?.cancel(); timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll()); }
  Future<dynamic> _request(String path, {Map<String, dynamic>? body}) async {
    final headers = {'Content-Type': 'application/json', if (token != null) 'x-recovery-token': token!};
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/recovery/$path');
    final response = await (body == null ? http.get(uri, headers: headers) : http.post(uri, headers: headers, body: jsonEncode(body))).timeout(const Duration(seconds: 15));
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) { await storage.delete(key: 'recovery_token'); token = null; timer?.cancel(); }
    if (response.statusCode < 200 || response.statusCode >= 300) throw AuthException(data is Map ? data['message']?.toString() ?? 'Request failed' : 'Request failed');
    return data;
  }
  Future<void> _poll() async {
    if (polling || token == null || !mounted) return;
    polling = true;
    try {
      final data = await _request('messages');
      if (mounted) setState(() { messages = (data['messages'] as List).map((e) => Map<String,dynamic>.from(e)).toList(); closed = data['status'] == 'CLOSED'; error = null; });
    } catch (e) { if (mounted) setState(() => error = clientErrorMessage(e)); }
    finally { polling = false; }
  }
  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try { await action(); } catch (e) { if (mounted) setState(() => error = clientErrorMessage(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _connect() => _run(() async {
    final number = internationalPhone(phone.text, country.countryCode);
    if (number == null) throw const AuthException('Enter your registered mobile number');
    final data = await _request('open', body: {'phone': number});
    token = data['token'] as String;
    await storage.write(key: 'recovery_token', value: token);
    if (!mounted) return;
    await _poll(); _startPolling();
  });
  Future<void> _send() => _run(() async {
    if (message.text.trim().isEmpty) return;
    await _request('messages', body: {'content': message.text.trim()});
    message.clear(); await _poll();
  });
  Future<void> _reset() => _run(() async {
    if (password.text.length < 8 || password.text != confirm.text) throw const AuthException('Enter matching passwords of at least 8 characters');
    await _request('reset', body: {'code': code.text.trim(), 'newPassword': password.text});
    await storage.delete(key: 'recovery_token');
    await AuthService().disableBiometricQuickLogin();
    if (!mounted) return;
    timer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated. Please log in.')));
    Navigator.pop(context);
  });
  @override
  void dispose() { timer?.cancel(); for (final c in [phone,message,code,password,confirm]) { c.dispose(); } super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.white,
    appBar: AppBar(title: const Text('Customer Support')),
    body: !ready ? const Center(child: CircularProgressIndicator()) : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: ListView(padding: const EdgeInsets.all(20), children: [
      const VerificationBanner(title: 'Password Recovery', subtitle: 'Customer Support', icon: Icons.support_agent),
      const SizedBox(height: 20),
      if (token == null) ...[
        InternationalPhoneField(controller: phone, country: country, enabled: !busy, onCountryChanged: (c) => setState(() => country = c)),
        const SizedBox(height: 16), FilledButton.icon(onPressed: busy ? null : _connect, icon: const Icon(Icons.chat_bubble_outline), label: const Text('Connect to Support')),
      ] else ...[
        if (messages.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('Waiting for a support agent', textAlign: TextAlign.center)),
        for (final item in messages) Align(alignment: item['sender'] == 'CLIENT' ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(constraints: const BoxConstraints(maxWidth: 330), margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: item['sender'] == 'CLIENT' ? const Color(0xFFEAF1FF) : const Color(0xFFF5F6F8), borderRadius: BorderRadius.circular(6)), child: SelectableText(item['content'] as String))),
        if (!closed) ...[
          Row(children: [Expanded(child: TextField(controller: message, minLines: 1, maxLines: 4, maxLength: 2000, decoration: onboardingInput('Message').copyWith(counterText: ''))), IconButton(tooltip: 'Send message', onPressed: busy ? null : _send, icon: const Icon(Icons.send, color: AppConfig.primaryColor))]),
          const SizedBox(height: 24), const Divider(), const SizedBox(height: 12),
          const Text('Reset Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 16),
          TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: onboardingInput('Reset code from support')),
          const SizedBox(height: 12), TextField(controller: password, obscureText: obscure, decoration: onboardingInput('New password').copyWith(suffixIcon: IconButton(tooltip: 'Show password', onPressed: () => setState(() => obscure = !obscure), icon: const Icon(Icons.visibility_outlined)))),
          const SizedBox(height: 12), TextField(controller: confirm, obscureText: obscure, decoration: onboardingInput('Confirm password')),
          const SizedBox(height: 16), FilledButton(onPressed: busy ? null : _reset, child: const Text('Update Password')),
        ] else ...[
          const Text('This support request is closed.'), TextButton(onPressed: () async { await storage.delete(key: 'recovery_token'); if (mounted) setState(() { token = null; closed = false; messages = []; }); }, child: const Text('New support request')),
        ],
      ],
      if (busy) const LinearProgressIndicator(),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: AppConfig.lossColor))),
    ]))),
  );
}

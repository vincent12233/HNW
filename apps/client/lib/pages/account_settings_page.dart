import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import '../app_config.dart';
import '../services/auth_service.dart';
import '../services/client_account_service.dart';
import '../utils/client_error_message.dart';
import '../utils/number_formatters.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key, required this.section});
  final String section;
  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final service = ClientAccountService();
  final authService = AuthService();
  bool loading = true;
  dynamic data;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (widget.section == 'profile') data = await service.profile();
      if (widget.section == 'banks') data = await service.banks();
      if (widget.section == 'devices') data = await service.devices();
      if (widget.section == 'preferences') data = await service.preferences();
      if (widget.section == 'reconciliation')
        data = await service.reconciliation();
      if (widget.section == 'kyc') data = await service.kycStatus();
    } on AuthException catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title)),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: TextButton(onPressed: load, child: Text(error!)),
          )
        : _body(),
  );
  String get _title =>
      {
        'profile': 'Personal Information',
        'banks': 'Bank Accounts',
        'security': 'Security',
        'devices': 'Login Devices',
        'preferences': 'Preferences',
        'reconciliation': 'Portfolio Reconciliation',
        'kyc': 'KYC & Verification',
      }[widget.section] ??
      'Account';
  Widget _body() {
    if (widget.section == 'profile') return _profile();
    if (widget.section == 'banks') return _banks();
    if (widget.section == 'security') return _security();
    if (widget.section == 'devices') return _devices();
    if (widget.section == 'preferences') return _preferences();
    if (widget.section == 'kyc') return _kyc();
    return _reconciliation();
  }

  Widget _profile() {
    final name = TextEditingController(text: data['fullName']?.toString());
    final email = TextEditingController(text: data['email']?.toString());
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: email,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () async {
            await service.updateProfile(name.text, email.text);
            if (mounted) Navigator.pop(context, true);
          },
          child: const Text('Save changes'),
        ),
      ],
    );
  }

  Widget _banks() {
    final rows = (data as List<Map<String, dynamic>>);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...rows.map(
          (bank) => Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance),
              title: Text(bank['bankName']?.toString() ?? ''),
              subtitle: Text(
                '•••• ${bank['accountNumber'].toString().substring(bank['accountNumber'].toString().length - 4)} · ${bank['status']}',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _addBank,
          icon: const Icon(Icons.add),
          label: const Text('Add bank account'),
        ),
      ],
    );
  }

  Future<void> _addBank() async {
    final bank = TextEditingController(),
        holder = TextEditingController(),
        number = TextEditingController(),
        ifsc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add bank account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bank,
                decoration: const InputDecoration(labelText: 'Bank name'),
              ),
              TextField(
                controller: holder,
                decoration: const InputDecoration(labelText: 'Account holder'),
              ),
              TextField(
                controller: number,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Account number'),
              ),
              TextField(
                controller: ifsc,
                decoration: const InputDecoration(labelText: 'IFSC code'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Add account'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await service.addBank({
        'bankName': bank.text,
        'accountHolder': holder.text,
        'accountNumber': number.text,
        'ifscCode': ifsc.text,
      });
      await load();
    }
  }

  Widget _security() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      ListTile(
        leading: const Icon(Icons.password),
        title: const Text('Change password'),
        onTap: _changePassword,
      ),
      ListTile(
        leading: const Icon(Icons.devices),
        title: const Text('Login devices'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AccountSettingsPage(section: 'devices'),
          ),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.g_mobiledata_rounded),
        title: const Text('Link Google account'),
        subtitle: const Text('Google email must match Personal Information'),
        onTap: _linkGoogle,
      ),
      ListTile(
        leading: const Icon(Icons.fingerprint_rounded),
        title: const Text('Face ID / fingerprint'),
        subtitle: const Text('Configure biometric quick login'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AccountSettingsPage(section: 'preferences'),
          ),
        ),
      ),
    ],
  );

  Future<void> _linkGoogle() async {
    try {
      final account = await GoogleSignIn(
        scopes: const ['email'],
        clientId: AppConfig.googleClientId.isEmpty
            ? null
            : AppConfig.googleClientId,
        serverClientId: AppConfig.googleClientId.isEmpty
            ? null
            : AppConfig.googleClientId,
      ).signIn();
      if (account == null) return;
      final token = (await account.authentication).idToken;
      if (token == null) {
        throw AuthException('Google did not return a valid identity token');
      }
      await authService.linkGoogle(token);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Google account linked')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(clientErrorMessage(error))));
      }
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController(), next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await service.changePassword(current.text, next.text);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password changed')));
    }
  }

  Widget _devices() => ListView(
    children: (data as List<Map<String, dynamic>>)
        .map(
          (d) => ListTile(
            leading: const Icon(Icons.phone_android),
            title: Text(d['deviceName']?.toString() ?? 'Device'),
            subtitle: Text(d['platform']?.toString() ?? ''),
            trailing: TextButton(
              onPressed: () async {
                await service.revokeDevice(d['id'].toString());
                await load();
              },
              child: const Text('Remove'),
            ),
          ),
        )
        .toList(),
  );
  Widget _preferences() {
    final p = Map<String, dynamic>.from(data as Map);
    return ListView(
      children:
          [
                'orderNotifications',
                'accountNotifications',
                'supportNotifications',
                'biometricEnabled',
              ]
              .map(
                (key) => SwitchListTile(
                  value: p[key] == true,
                  title: Text(
                    {
                      'orderNotifications': 'Order notifications',
                      'accountNotifications': 'Account notifications',
                      'supportNotifications': 'Customer service notifications',
                      'biometricEnabled': 'Biometric login',
                    }[key]!,
                  ),
                  onChanged: (v) async {
                    if (key == 'biometricEnabled') {
                      try {
                        if (v) {
                          final localAuth = LocalAuthentication();
                          if (!await localAuth.isDeviceSupported()) {
                            throw AuthException(
                              'Biometric authentication is not available',
                            );
                          }
                          final verified = await localAuth.authenticate(
                            localizedReason: 'Enable biometric quick login',
                            options: const AuthenticationOptions(
                              biometricOnly: true,
                              stickyAuth: true,
                            ),
                          );
                          if (!verified) return;
                          await authService.enableBiometricQuickLogin();
                        } else {
                          await authService.disableBiometricQuickLogin();
                        }
                      } catch (error) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(clientErrorMessage(error))),
                          );
                        }
                        return;
                      }
                    }
                    p[key] = v;
                    setState(() => data = p);
                    await service.updatePreferences({key: v});
                  },
                ),
              )
              .toList(),
    );
  }

  Widget _reconciliation() {
    final r = Map<String, dynamic>.from(data as Map);
    final c = Map<String, dynamic>.from(r['categories'] as Map);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: const Text('Total assets'),
            trailing: Text(formatPriceValue(r['totalAssets'])),
          ),
        ),
        Card(
          child: Column(
            children: c.entries
                .map(
                  (e) => ListTile(
                    title: Text(e.key),
                    trailing: Text(formatPriceValue(e.value)),
                  ),
                )
                .toList(),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.verified, color: Colors.green),
          title: Text(
            r['balanced'] == true ? 'Account reconciled' : 'Review required',
          ),
          subtitle: Text('As of ${r['asOf']}'),
        ),
      ],
    );
  }

  Widget _kyc() {
    final k = Map<String, dynamic>.from(data as Map);
    final status = k['status']?.toString() ?? 'NOT_SUBMITTED';
    return Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                status == 'APPROVED'
                    ? Icons.verified_user
                    : Icons.hourglass_top,
                size: 52,
                color: status == 'APPROVED' ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 14),
              Text(
                status,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                k['reviewNote']?.toString() ??
                    'Your latest KYC verification status is shown here.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

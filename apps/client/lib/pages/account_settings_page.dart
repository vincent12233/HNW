import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import '../app_config.dart';
import '../services/auth_service.dart';
import '../services/device_biometrics.dart';
import '../services/client_account_service.dart';
import '../utils/client_error_message.dart';
import '../utils/number_formatters.dart';
import 'kyc_upload_page.dart';
import 'bank_details_page.dart';

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
  DeviceBiometric? biometric;
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
      biometric = await DeviceBiometrics.available();
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
    final profile = data is Map
        ? Map<String, dynamic>.from(data as Map)
        : <String, dynamic>{};
    final name = TextEditingController(text: profile['fullName']?.toString());
    final email = TextEditingController(text: profile['email']?.toString());
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
            final fullName = name.text.trim();
            final emailAddress = email.text.trim().toLowerCase();
            if (fullName.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter your full name')),
              );
              return;
            }
            if (emailAddress.isNotEmpty &&
                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(emailAddress)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a valid email address')),
              );
              return;
            }
            if (emailAddress.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter your email address')),
              );
              return;
            }
            try {
              await service.updateProfile(fullName, emailAddress);
              await authService.updateCachedFullName(fullName);
              if (mounted) Navigator.pop(context, true);
            } catch (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(clientErrorMessage(error))),
                );
              }
            }
          },
          child: const Text('Save changes'),
        ),
      ],
    );
  }

  Widget _banks() {
    final rows = data is List
        ? (data as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
        : <Map<String, dynamic>>[];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_outlined,
                  size: 48,
                  color: Colors.black38,
                ),
                SizedBox(height: 12),
                Text('No bank account linked'),
                SizedBox(height: 4),
                Text(
                  'Add an approved bank account before withdrawing funds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ...rows.map(
          (bank) => Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance),
              title: Text(bank['bankName']?.toString() ?? ''),
              subtitle: Text(_bankSubtitle(bank)),
              trailing: IconButton(
                tooltip: 'Remove bank account',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _deleteBank(bank),
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

  Future<void> _deleteBank(Map<String, dynamic> bank) async {
    final id = bank['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove bank account?'),
        content: Text(
          'You will no longer be able to withdraw to ${bank['bankName'] ?? 'this account'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await service.deleteBank(id);
      if (mounted) await load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(clientErrorMessage(error))));
      }
    }
  }

  String _bankSubtitle(Map<String, dynamic> bank) {
    final number = bank['accountNumber']?.toString() ?? '';
    final suffix = number.length <= 4
        ? number
        : number.substring(number.length - 4);
    final masked = suffix.isEmpty
        ? 'Account number unavailable'
        : '•••• $suffix';
    final status = bank['status']?.toString().trim() ?? '';
    return status.isEmpty ? masked : '$masked · $status';
  }

  Future<void> _addBank() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const BankDetailsPage()),
    );
    if (saved == true && mounted) await load();
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
            onPressed: () {
              final currentPassword = current.text;
              final newPassword = next.text;
              String? message;
              if (currentPassword.isEmpty) {
                message = 'Enter your current password';
              } else if (newPassword.length < 8) {
                message = 'New password must contain at least 8 characters';
              } else if (newPassword == currentPassword) {
                message = 'New password must be different';
              }
              if (message != null) {
                ScaffoldMessenger.of(c)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(message)));
                return;
              }
              Navigator.pop(c, true);
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await service.changePassword(current.text, next.text);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Password changed')));
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(clientErrorMessage(error))));
        }
      }
    }
  }

  Widget _devices() => ListView(
    children: (data is List ? data as List : const <dynamic>[])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
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
    final p = data is Map
        ? Map<String, dynamic>.from(data as Map)
        : <String, dynamic>{};
    return ListView(
      children:
          [
                'orderNotifications',
                'accountNotifications',
                'supportNotifications',
                if (biometric != null) 'biometricEnabled',
              ]
              .map(
                (key) => SwitchListTile(
                  value: p[key] == true,
                  title: Text(
                    {
                      'orderNotifications': 'Order notifications',
                      'accountNotifications': 'Account notifications',
                      'supportNotifications': 'Customer service notifications',
                      'biometricEnabled': biometric == DeviceBiometric.face ? 'Face ID login' : 'Fingerprint login',
                    }[key]!,
                  ),
                  onChanged: (v) async {
                    if (key == 'biometricEnabled') {
                      try {
                        if (v) {
                          final localAuth = LocalAuthentication();
                          if (await DeviceBiometrics.available() == null) {
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
                    try {
                      await service.updatePreferences({key: v});
                      if (!mounted) return;
                      p[key] = v;
                      setState(() => data = p);
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(clientErrorMessage(error))),
                        );
                      }
                    }
                  },
                ),
              )
              .toList(),
    );
  }

  Widget _reconciliation() {
    final r = data is Map
        ? Map<String, dynamic>.from(data as Map)
        : <String, dynamic>{};
    final c = r['categories'] is Map
        ? Map<String, dynamic>.from(r['categories'] as Map)
        : <String, dynamic>{};
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
    final k = data is Map
        ? Map<String, dynamic>.from(data as Map)
        : <String, dynamic>{};
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
              if (status != 'APPROVED') ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _startKyc,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(
                    status == 'NOT_SUBMITTED'
                        ? 'Start verification'
                        : 'Update documents',
                  ),
                ),
              ],
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

  Future<void> _startKyc() async {
    final session = await authService.restoreSession();
    if (!mounted) return;
    final phone = session?.phone.trim() ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in again to update KYC details')),
      );
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const KycUploadPage()));
    if (mounted) await load();
  }
}

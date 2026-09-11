import '../widgets/app_page_scaffold.dart';
import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import '../app_config.dart';
import '../services/auth_service.dart';
import '../services/client_account_service.dart';
import '../utils/client_error_message.dart';
import '../utils/number_formatters.dart';
import 'kyc_upload_page.dart';
import 'bank_details_page.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({
    super.key,
    required this.section,
    this.accountService,
  });
  final String section;
  final ClientAccountService? accountService;
  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  late final service = widget.accountService ?? ClientAccountService();
  final authService = AuthService();
  bool loading = true;
  bool _savingProfile = false;
  bool _deletingBank = false;
  dynamic data;
  String? error;
  int _loadGeneration = 0;
  final Set<String> _savingPreferences = <String>{};
  final _profileNameController = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      dynamic nextData;
      if (widget.section == 'profile') {
        nextData = await service.profile();
      }
      if (widget.section == 'banks') nextData = await service.banks();
      if (widget.section == 'preferences') {
        nextData = await service.preferences();
      }
      if (widget.section == 'reconciliation') {
        nextData = await service.reconciliation();
      }
      if (widget.section == 'kyc') nextData = await service.kycStatus();
      if (!mounted || generation != _loadGeneration) return;
      if (widget.section == 'profile') {
        final profile = nextData is Map
            ? Map<String, dynamic>.from(nextData)
            : <String, dynamic>{};
        _profileNameController.text = profile['fullName']?.toString() ?? '';
      }
      setState(() {
        data = nextData;
        loading = false;
      });
    } on AuthException catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        this.error = clientErrorMessage(error);
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    _profileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPageScaffold(
    appBar: AppBar(title: AppText(_title)),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? AppEmptyState(
            title: 'Unable to load account',
            message: error,
            icon: Icons.cloud_off_outlined,
            onRetry: load,
          )
        : _body(),
  );
  String get _title =>
      {
        'profile': 'Personal Information',
        'banks': 'Bank Accounts',
        'preferences': 'Preferences',
        'reconciliation': 'Portfolio Reconciliation',
        'kyc': 'KYC & Verification',
      }[widget.section] ??
      'Account';
  Widget _body() {
    if (widget.section == 'profile') return _profile();
    if (widget.section == 'banks') return _banks();
    if (widget.section == 'preferences') return _preferences();
    if (widget.section == 'kyc') return _kyc();
    return _reconciliation();
  }

  Widget _profile() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const AppText('Account ID'),
          subtitle: SelectableText(
            data?['account']?['accountNumber']?.toString() ??
                data?['id']?.toString() ??
                '--',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _profileNameController,
          enabled: !_savingProfile,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          decoration: InputDecoration(labelText: tr('Full name')),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _savingProfile
              ? null
              : () async {
                  if (_savingProfile) return;
                  final fullName = _profileNameController.text.trim();
                  if (fullName.length < 2) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: AppText('Enter your full name')),
                    );
                    return;
                  }
                  setState(() => _savingProfile = true);
                  try {
                    await service.updateProfile(fullName);
                    await authService.updateCachedFullName(fullName);
                    if (mounted) Navigator.pop(context, true);
                  } catch (error) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: AppText(clientErrorMessage(error))),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _savingProfile = false);
                  }
                },
          child: _savingProfile
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const AppText('Save changes'),
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
                AppText('No bank account linked'),
                SizedBox(height: 4),
                AppText(
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
              title: AppText(bank['bankName']?.toString() ?? ''),
              subtitle: AppText(_bankSubtitle(bank)),
              trailing: IconButton(
                tooltip: 'Remove bank account',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _deletingBank ? null : () => _deleteBank(bank),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _deletingBank ? null : _addBank,
          icon: const Icon(Icons.add),
          label: const AppText('Add bank account'),
        ),
      ],
    );
  }

  Future<void> _deleteBank(Map<String, dynamic> bank) async {
    final id = bank['id']?.toString() ?? '';
    if (id.isEmpty || _deletingBank) return;
    setState(() => _deletingBank = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const AppText('Remove bank account?'),
          content: AppText(
            'You will no longer be able to withdraw to ${bank['bankName'] ?? 'this account'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const AppText('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      try {
        await service.deleteBank(id);
        if (mounted) await load();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: AppText(clientErrorMessage(error))));
        }
      }
    } finally {
      if (mounted) setState(() => _deletingBank = false);
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

  Widget _preferences() {
    final preferences = data is Map
        ? Map<String, dynamic>.from(data as Map)
        : <String, dynamic>{};
    const labels = {
      'orderNotifications': 'Order notifications',
      'accountNotifications': 'Account notifications',
      'supportNotifications': 'Customer service notifications',
    };
    return ListView(
      children: labels.entries
          .map(
            (entry) => SwitchListTile(
              title: AppText(entry.value),
              value: preferences[entry.key] == true,
              onChanged: _savingPreferences.contains(entry.key)
                  ? null
                  : (value) async {
                      if (_savingPreferences.contains(entry.key)) return;
                      setState(() => _savingPreferences.add(entry.key));
                      try {
                        await service.updatePreferences({entry.key: value});
                        if (mounted) {
                          setState(
                            () => data = {
                              if (data is Map)
                                ...Map<String, dynamic>.from(data as Map),
                              entry.key: value,
                            },
                          );
                        }
                      } catch (error) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: AppText(clientErrorMessage(error)),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _savingPreferences.remove(entry.key));
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
            title: const AppText('Total assets'),
            trailing: AppText(formatPriceValue(r['totalAssets'])),
          ),
        ),
        Card(
          child: Column(
            children: c.entries
                .map(
                  (e) => ListTile(
                    title: AppText(e.key),
                    trailing: AppText(formatPriceValue(e.value)),
                  ),
                )
                .toList(),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.verified, color: AppConfig.gainColor),
          title: AppText(
            r['balanced'] == true ? 'Account reconciled' : 'Review required',
          ),
          subtitle: AppText('As of ${r['asOf']}'),
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
                color: status == 'APPROVED'
                    ? AppConfig.gainColor
                    : status == 'REJECTED'
                    ? AppConfig.lossColor
                    : AppConfig.neutralColor,
              ),
              const SizedBox(height: 14),
              AppText(
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
                  label: AppText(
                    status == 'NOT_SUBMITTED'
                        ? 'Start verification'
                        : 'Update documents',
                  ),
                ),
              ],
              const SizedBox(height: 8),
              AppText(
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
        const SnackBar(content: AppText('Sign in again to update KYC details')),
      );
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const KycUploadPage()));
    if (mounted) await load();
  }
}

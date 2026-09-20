import '../widgets/app_page_scaffold.dart';
import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import '../app_config.dart';
import '../services/auth_service.dart';
import '../services/client_account_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/client_error_message.dart';
import '../utils/number_formatters.dart';
import '../widgets/profile_identity.dart';
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
  final Set<String> _revealedBanks = <String>{};
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
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppSpacing.md),
                  AppText('Loading account'),
                ],
              ),
            ),
          )
        : error != null
        ? AppEmptyState(
            title: 'Unable to load account',
            message: error,
            icon: Icons.cloud_off_outlined,
            onRetry: load,
          )
        : AppFadeIn(switchKey: widget.section, child: _body()),
  );
  String get _title =>
      {
        'profile': 'Personal Information',
        'banks': 'Bank Accounts',
        'preferences': 'Alert Preferences',
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
        const AppText(
          'Account ID is assigned by the server and cannot be edited here.',
          style: AppTypography.caption,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const AppText('Account ID'),
          subtitle: SelectableText(
            data?['account']?['accountNumber']?.toString() ??
                data?['id']?.toString() ??
                '--',
          ),
          trailing: const AppText(
            'Read-only',
            style: AppTypography.caption,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _profileNameController,
          enabled: !_savingProfile,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          decoration: InputDecoration(
            labelText: tr('Full name'),
            helperText: 'This is the only profile field that can be saved.',
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: AppMotion.tapTarget,
          child: FilledButton(
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
                  'Add a bank account before withdrawing funds. Saved details are not a completed bank verification.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ...rows.map((bank) {
          final id = bank['id']?.toString() ?? '';
          final revealed = _revealedBanks.contains(id);
          return Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_balance),
                    title: AppText(
                      bank['bankName']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: AppText(_bankSubtitle(bank, revealed: revealed)),
                  ),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: revealed
                            ? 'Hide account number'
                            : 'Show account number',
                        constraints: const BoxConstraints(
                          minWidth: AppMotion.tapTarget,
                          minHeight: AppMotion.tapTarget,
                        ),
                        onPressed: id.isEmpty
                            ? null
                            : () => setState(() {
                                if (revealed) {
                                  _revealedBanks.remove(id);
                                } else {
                                  _revealedBanks.add(id);
                                }
                              }),
                        icon: Icon(
                          revealed ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove bank account',
                        constraints: const BoxConstraints(
                          minWidth: AppMotion.tapTarget,
                          minHeight: AppMotion.tapTarget,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: _deletingBank
                            ? null
                            : () => _deleteBank(bank),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
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

  String _bankSubtitle(Map<String, dynamic> bank, {required bool revealed}) {
    final number = bank['accountNumber']?.toString() ?? '';
    final display = number.isEmpty
        ? 'Account number unavailable'
        : revealed
        ? number
        : (number.length <= 4
              ? '•••• $number'
              : '•••• ${number.substring(number.length - 4)}');
    final status = bank['status']?.toString().trim() ?? '';
    final note = status.isEmpty ? 'Not a completed bank verification' : status;
    return '$display · $note';
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
    final label = profileKycLabel(status);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Icon(
                status == 'APPROVED'
                    ? Icons.badge_outlined
                    : status == 'REJECTED'
                    ? Icons.error_outline
                    : Icons.hourglass_top,
                size: 52,
                color: profileKycColor(status) == AppColors.textSecondary
                    ? AppConfig.neutralColor
                    : profileKycColor(status),
              ),
              const SizedBox(height: 14),
              AppText(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const AppText(
                'Review is completed by the operations team. This screen does not confirm identity or bank checks automatically.',
                textAlign: TextAlign.center,
              ),
              if (status != 'APPROVED') ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _startKyc,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: AppText(
                    status == 'REJECTED'
                        ? 'Resubmit documents'
                        : status == 'NOT_SUBMITTED'
                        ? 'Start verification'
                        : 'Update documents',
                  ),
                ),
              ],
              const SizedBox(height: 8),
              AppText(
                k['reviewNote']?.toString().trim().isNotEmpty == true
                    ? k['reviewNote'].toString()
                    : 'Your latest KYC verification status is shown here.',
                textAlign: TextAlign.center,
              ),
              ],
            ),
          ),
        ),
      ],
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

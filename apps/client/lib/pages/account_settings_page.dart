import 'dart:async';

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
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/membership_tier_badge.dart';
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
  Future<void>? _inFlight;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    _loadGeneration++;
    _profileNameController.dispose();
    super.dispose();
  }

  Future<void> load() {
    final pending = _inFlight;
    if (pending != null) return pending;
    if (!mounted) return Future.value();
    final future = _loadOnce();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<void> _loadOnce() async {
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
        error = null;
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
  Widget build(BuildContext context) => AppPageScaffold(
    appBar: AppBar(
      title: AppText(
        _title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: loading && data == null && error == null
        ? const AppLoadingView(message: 'Loading account')
        : error != null && data == null
        ? AppErrorView(
            title: 'Unable to load account',
            message: error,
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
    final profile = data is Map
        ? Map<String, dynamic>.from(data as Map)
        : <String, dynamic>{};
    final accountId =
        profile['account']?['accountNumber']?.toString() ??
        profile['customerNo']?.toString() ??
        profile['id']?.toString();
    final phone = profile['phone']?.toString() ?? '';
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return ListView(
      padding: AppSpacing.page.add(EdgeInsets.only(bottom: bottomInset)),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const AppText(
          'Account ID is assigned by the server and cannot be edited here.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _readonlyRow('Account ID', displayOrUnavailable(accountId)),
              _readonlyRow(
                'Mobile number',
                phone.trim().isEmpty ? 'Unavailable' : maskAccountPhone(phone),
              ),
              _readonlyRow(
                'Account status',
                displayOrUnavailable(profile['status']),
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Row(
                  children: [
                    const Expanded(
                      child: AppText(
                        'Client tier',
                        style: AppTypography.caption,
                      ),
                    ),
                    MembershipTierBadge(
                      tier: profile['clientTier']?.toString(),
                    ),
                  ],
                ),
              ),
              _readonlyRow(
                'Account opened',
                _profileDate(profile['createdAt']),
              ),
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: AppText(
                  'Read-only',
                  style: AppTypography.caption,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
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
        const SizedBox(height: AppSpacing.xl),
        AppPrimaryButton(
          label: 'Save changes',
          loading: _savingProfile,
          onPressed: _savingProfile ? null : _saveProfile,
        ),
      ],
    );
  }

  Future<void> _saveProfile() async {
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
      final saved = await service.updateProfile(fullName);
      if (!mounted) return;
      final confirmed =
          saved['fullName']?.toString().trim().isNotEmpty == true
          ? saved['fullName'].toString().trim()
          : fullName;
      _profileNameController.text = confirmed;
      try {
        await authService.updateCachedFullName(confirmed);
      } catch (_) {}
      Map<String, dynamic>? refreshed;
      try {
        refreshed = await service.profile();
      } catch (_) {
        refreshed = null;
      }
      if (!mounted) return;
      if (refreshed != null) {
        setState(() {
          data = refreshed;
          _profileNameController.text =
              refreshed!['fullName']?.toString() ?? confirmed;
        });
      }
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
  }

  Widget _readonlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppText(label, style: AppTypography.caption),
          ),
          Flexible(
            child: AppText(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _profileDate(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) return 'Unavailable';
    return formatAppDateTime(parsed).split(',').first;
  }

  Widget _banks() {
    final rows = data is List
        ? (data as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
        : <Map<String, dynamic>>[];
    return ListView(
      padding: AppSpacing.page,
      children: [
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          AppErrorView(
            title: error!,
            onRetry: loading || _deletingBank ? null : load,
            compact: true,
          ),
        const AppText(
          'Saved bank details are used for withdrawals after finance review. This is not a completed bank verification.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (rows.isEmpty)
          const AppEmptyState(
            compact: true,
            title: 'No bank account linked',
            message:
                'Add a bank account before withdrawing funds. Saved details are not a completed bank verification.',
            icon: Icons.account_balance_outlined,
          )
        else
          for (final bank in rows) _bankCard(bank),
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(
          label: 'Add bank account',
          icon: Icons.add,
          onPressed: _deletingBank || loading ? null : _addBank,
        ),
      ],
    );
  }

  Widget _bankCard(Map<String, dynamic> bank) {
    final id = bank['id']?.toString() ?? '';
    final revealed = _revealedBanks.contains(id);
    final name = displayOrUnavailable(bank['bankName']);
    final holder = displayOrUnavailable(bank['accountHolder']);
    final status = bank['status']?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(name, style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            AppText(
              maskBankAccountNumber(
                bank['accountNumber']?.toString() ?? '',
                revealed: revealed,
              ),
            ),
            AppText(
              'IFSC ${maskIfscCode(bank['ifscCode']?.toString() ?? '', revealed: revealed)}',
            ),
            AppText('Holder $holder'),
            AppText(
              status.isEmpty ? 'Not a completed bank verification' : status,
              style: AppTypography.caption,
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
                  onPressed: _deletingBank || loading || error != null || id.isEmpty
                      ? null
                      : () => _deleteBank(bank),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBank(Map<String, dynamic> bank) async {
    final id = bank['id']?.toString() ?? '';
    if (id.isEmpty || _deletingBank || loading || error != null) return;
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
      padding: AppSpacing.page,
      children: [
        const AppText(
          'These switches save to the server. A failed change is not kept as saved.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final entry in labels.entries)
          SwitchListTile(
            title: AppText(entry.value),
            secondary: _savingPreferences.contains(entry.key)
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
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
      ],
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
      padding: AppSpacing.page,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText('Total assets', style: AppTypography.caption),
              AppText(formatPriceValue(r['totalAssets']), style: AppTypography.titleMedium),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in c.entries) ...[
                AppText(e.key, style: AppTypography.caption),
                AppText(formatPriceValue(e.value), style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified, color: AppConfig.gainColor),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    r['balanced'] == true
                        ? 'Account reconciled'
                        : 'Review required',
                  ),
                  AppText(
                    r['asOf'] == null || r['asOf'].toString().trim().isEmpty
                        ? 'Unavailable'
                        : 'As of ${r['asOf']}',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ],
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
      padding: AppSpacing.page,
      children: [
        AppCard(
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
              const SizedBox(height: AppSpacing.lg),
              AppText(label, style: AppTypography.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              const AppText(
                'Review is completed by the operations team. This screen does not confirm identity or bank checks automatically.',
                textAlign: TextAlign.center,
              ),
              if (status != 'APPROVED') ...[
                const SizedBox(height: AppSpacing.lg),
                AppPrimaryButton(
                  label: status == 'REJECTED'
                      ? 'Resubmit documents'
                      : status == 'NOT_SUBMITTED'
                      ? 'Start verification'
                      : 'Update documents',
                  icon: Icons.upload_file_rounded,
                  onPressed: _startKyc,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              AppText(
                k['reviewNote']?.toString().trim().isNotEmpty == true
                    ? k['reviewNote'].toString()
                    : 'Your latest KYC verification status is shown here.',
                textAlign: TextAlign.center,
              ),
            ],
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

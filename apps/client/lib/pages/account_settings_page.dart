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

part 'account_settings_page_profile_section.dart';
part 'account_settings_page_banks_section.dart';
part 'account_settings_page_preferences_section.dart';

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
  void _setState(VoidCallback fn) => setState(fn);
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
      title: AppText(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
              AppText(
                formatPriceValue(r['totalAssets']),
                style: AppTypography.titleMedium,
              ),
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
                AppText(
                  formatPriceValue(e.value),
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              r['balanced'] == true
                  ? Icons.verified_outlined
                  : Icons.warning_amber_rounded,
              color: r['balanced'] == true ? AppColors.gain : AppColors.warning,
            ),
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

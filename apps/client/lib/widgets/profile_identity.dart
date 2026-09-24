import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/membership_tier_badge.dart';

String maskAccountPhone(String phone) {
  final trimmed = phone.trim();
  if (trimmed.isEmpty || trimmed == '--') return '--';
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return '****';
  final suffix = digits.substring(digits.length - 4);
  return '+91 ******$suffix';
}

String displayOrUnavailable(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text == '--') return 'Unavailable';
  return text;
}

String maskBankAccountNumber(String number, {required bool revealed}) {
  final trimmed = number.trim();
  if (trimmed.isEmpty) return 'Unavailable';
  if (revealed) return trimmed;
  if (trimmed.length <= 4) return '•••• $trimmed';
  return '•••• ${trimmed.substring(trimmed.length - 4)}';
}

String maskIfscCode(String ifsc, {required bool revealed}) {
  final trimmed = ifsc.trim().toUpperCase();
  if (trimmed.isEmpty) return 'Unavailable';
  if (revealed) return trimmed;
  if (trimmed.length <= 4) return '••••';
  return '${trimmed.substring(0, 4)}••••';
}

String profileKycLabel(String status) {
  switch (status.trim().toUpperCase()) {
    case 'APPROVED':
      return 'APPROVED';
    case 'PENDING':
      return 'PENDING';
    case 'REJECTED':
      return 'REJECTED';
    case 'NOT_SUBMITTED':
      return 'Not started';
    case 'IN_PROGRESS':
      return 'In progress';
    case 'UNKNOWN':
    case '':
      return 'Status unavailable';
    default:
      return status.trim().toUpperCase();
  }
}

Color profileKycColor(String status) {
  switch (status.trim().toUpperCase()) {
    case 'APPROVED':
      return AppColors.gain;
    case 'REJECTED':
      return AppColors.loss;
    case 'PENDING':
    case 'IN_PROGRESS':
      return AppColors.warning;
    default:
      return AppColors.textSecondary;
  }
}

Color profileAccountStatusColor(String status, {required Color fallback}) {
  switch (status.trim().toUpperCase()) {
    case 'ACTIVE':
      return AppColors.gain;
    case 'SUSPENDED':
      return AppColors.warning;
    case 'DISABLED':
    case 'INACTIVE':
      return AppColors.loss;
    default:
      return fallback;
  }
}

IconData profileAccountStatusIcon(String status) {
  switch (status.trim().toUpperCase()) {
    case 'ACTIVE':
      return Icons.check_circle_outline;
    case 'SUSPENDED':
      return Icons.pause_circle_outline;
    case 'DISABLED':
    case 'INACTIVE':
      return Icons.block_outlined;
    default:
      return Icons.info_outline;
  }
}

String profileInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'C';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class ProfileIdentityHeader extends StatelessWidget {
  const ProfileIdentityHeader({
    super.key,
    required this.name,
    required this.accountNumber,
    required this.phone,
    required this.kycStatus,
    required this.clientTier,
    required this.memberSince,
    required this.accountStatus,
    this.avatarBytes,
    this.onAvatarTap,
    this.onEdit,
  });

  final String name;
  final String accountNumber;
  final String phone;
  final String kycStatus;
  final String clientTier;
  final String memberSince;
  final String accountStatus;
  final Uint8List? avatarBytes;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final mutedInverse = AppColors.textInverse.withValues(alpha: 0.70);
    final kycLabel = profileKycLabel(kycStatus);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandPrimary, AppColors.brandGradientEnd],
        ),
        borderRadius: AppRadius.borderMd,
        boxShadow: const [
          BoxShadow(
            color: Color(0x262558D9),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: tr('Edit profile photo'),
                child: InkWell(
                  onTap: onAvatarTap,
                  child: Semantics(
                    button: true,
                    label: tr('Edit profile photo'),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.brandPrimarySoft,
                        backgroundImage: avatarBytes == null
                            ? null
                            : MemoryImage(avatarBytes!),
                        child: avatarBytes == null
                            ? AppText(
                                profileInitials(name),
                                style: const TextStyle(
                                  color: AppColors.brandPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      name.isEmpty ? '--' : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleLarge.copyWith(
                        color: AppColors.textInverse,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs + 1),
                    AppText(
                      maskAccountPhone(phone),
                      style: AppTypography.caption.copyWith(
                        color: mutedInverse,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    AppText(
                      '${tr('Account ID')}: ${accountNumber.isEmpty ? '--' : accountNumber}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: mutedInverse,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm + 2),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: AppSpacing.sm + 2,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _pill(
                            icon: kycStatus == 'APPROVED'
                                ? Icons.badge_outlined
                                : Icons.info_outline,
                            iconColor: kycStatus == 'APPROVED'
                                ? AppColors.gain
                                : mutedInverse,
                            label: 'KYC $kycLabel',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: tr('Edit profile'),
                  onPressed: onEdit,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: Icon(
                    Icons.edit_outlined,
                    color: mutedInverse,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl + 2),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.2;
              final items = <Widget>[
                _meta(
                  'Client Tier',
                  MembershipTierBadge(tier: clientTier),
                  mutedInverse,
                ),
                _meta(
                  'Member Since',
                  _statusLine(
                    Icons.calendar_month_outlined,
                    memberSince.isEmpty ? '--' : memberSince,
                    mutedInverse,
                  ),
                  mutedInverse,
                ),
                _meta(
                  'Account Status',
                  _statusLine(
                    profileAccountStatusIcon(accountStatus),
                    accountStatus.isEmpty ? '--' : accountStatus,
                    profileAccountStatusColor(
                      accountStatus,
                      fallback: AppColors.textInverse,
                    ),
                  ),
                  mutedInverse,
                ),
              ];
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in items) ...[
                      item,
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in items)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          right: AppSpacing.sm - 2,
                        ),
                        child: item,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _meta(String label, Widget value, Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: AppTypography.caption.copyWith(color: muted, fontSize: 10),
        ),
        const SizedBox(height: AppSpacing.xs + 1),
        value,
      ],
    );
  }

  Widget _statusLine(IconData icon, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.xs + 1),
        Expanded(
          child: AppText(
            text,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.clip,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm - 1,
        vertical: AppSpacing.xxs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.textInverse.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.textInverse.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: iconColor, size: 12),
          ),
          const SizedBox(width: AppSpacing.xxs + 2),
          Expanded(
            child: AppText(
              label,
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.clip,
              style: AppTypography.caption.copyWith(
                color: AppColors.textInverse,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import '../widgets/app_page_scaffold.dart';
import '../l10n/app_language.dart';
import '../services/app_content_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_card.dart';
import 'package:flutter/material.dart';

part 'legal_page_content.dart';

class LegalPage extends StatefulWidget {
  const LegalPage({super.key, required this.title});

  final String title;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  bool get _isPrivacy => widget.title.toLowerCase().contains('privacy');
  bool get _isRisk => widget.title.toLowerCase().contains('risk');
  AppContentBundle _content = AppContentBundle.empty;
  bool _loading = true;
  bool _couldNotRefresh = false;

  @override
  void initState() {
    super.initState();
    AppContentService.instance.addListener(_onContentChanged);
    _load();
  }

  void _onContentChanged() {
    if (mounted) setState(() => _content = AppContentService.instance.current);
  }

  @override
  void dispose() {
    AppContentService.instance.removeListener(_onContentChanged);
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (force) setState(() => _loading = true);
    final content = await AppContentService.instance.load(force: force);
    if (!mounted) return;
    setState(() {
      _content = content;
      _couldNotRefresh = AppContentService.instance.lastFetchFailed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final remote = _isRisk
        ? _content.riskDocument()
        : _isPrivacy
        ? _content.privacyDocument()
        : _content.termsDocument();
    final useRemote = remote.sections.isNotEmpty;
    final fallbackHeading = _isRisk
        ? 'Risk Disclosure'
        : (_isPrivacy ? 'Privacy Policy' : 'Terms of Service');
    final heading = useRemote
        ? (remote.title?.isNotEmpty == true ? remote.title! : fallbackHeading)
        : fallbackHeading;
    final effective = useRemote && remote.effective.isNotEmpty
        ? remote.effective
        : (_isRisk
              ? 'Effective 16 September 2026  •  Version 1.0'
              : 'Effective 13 August 2026  •  Version 1.0');
    final sections = useRemote
        ? remote.sections
              .map((section) => _LegalSection(section.heading, section.body))
              .toList()
        : (_isRisk
              ? _riskSections
              : (_isPrivacy ? _privacySections : _termsSections));

    return AppPageScaffold(
      appBar: AppBar(
        title: AppText(heading, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: tr('Refresh'),
            onPressed: _loading ? null : () => _load(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const AppLoadingView(message: 'Loading document')
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.xxxl + 4,
                  ),
                  children: [
                    AppCard(
                      backgroundColor: AppColors.brandPrimarySoft,
                      borderColor: AppColors.brandPrimary.withValues(
                        alpha: 0.14,
                      ),
                      shadow: AppCardShadow.none,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _isRisk
                                ? Icons.warning_amber_rounded
                                : _isPrivacy
                                ? Icons.privacy_tip_outlined
                                : Icons.gavel_outlined,
                            color: AppColors.brandPrimary,
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  heading,
                                  style: AppTypography.headline.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm - 2),
                                AppText(
                                  effective,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!useRemote || _couldNotRefresh) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        backgroundColor: AppColors.warningSoft,
                        borderColor: AppColors.warning.withValues(alpha: 0.22),
                        shadow: AppCardShadow.none,
                        child: AppText(
                          useRemote
                              ? 'Showing a previously loaded document. Updates could not be checked. Please try refreshing again.'
                              : 'Showing the bundled document. Connect and refresh to check the latest published version.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    ...sections.map(
                      (section) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              section.heading,
                              style: AppTypography.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm - 1),
                            AppText(
                              section.body,
                              style: AppTypography.bodyMedium.copyWith(
                                height: 1.55,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

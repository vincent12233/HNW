part of 'account_settings_page.dart';

extension _AccountSettingsProfileSection on _AccountSettingsPageState {
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
                child: AppText('Read-only', style: AppTypography.caption),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('Enter your full name')));
      return;
    }
    _setState(() => _savingProfile = true);
    try {
      final saved = await service.updateProfile(fullName);
      if (!mounted) return;
      final confirmed = saved['fullName']?.toString().trim().isNotEmpty == true
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
        _setState(() {
          data = refreshed;
          _profileNameController.text =
              refreshed!['fullName']?.toString() ?? confirmed;
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(clientErrorMessage(error))));
      }
    } finally {
      if (mounted) _setState(() => _savingProfile = false);
    }
  }

  Widget _readonlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: AppText(label, style: AppTypography.caption)),
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

}

part of 'account_settings_page.dart';

extension _AccountSettingsKycSection on _AccountSettingsPageState {
  Widget _kyc() {
    final k = data is Map
        ? Map<String, dynamic>.from(data as Map)
        : <String, dynamic>{};
    final status = k['status']?.toString() ?? 'NOT_SUBMITTED';
    final label = profileKycLabel(status);
    final decided = status == 'APPROVED' || status == 'REJECTED';
    final submitted = status != 'NOT_SUBMITTED';
    final reviewNote = k['reviewNote']?.toString().trim();
    final actionLabel = status == 'REJECTED'
        ? 'Resubmit documents'
        : status == 'NOT_SUBMITTED'
        ? 'Start verification'
        : 'Update documents';
    return ListView(
      padding: AppSpacing.page,
      children: [
        AppStatusScene(
          icon: status == 'APPROVED'
              ? Icons.verified_user_outlined
              : status == 'REJECTED'
              ? Icons.assignment_late_outlined
              : status == 'PENDING'
              ? Icons.fact_check_outlined
              : Icons.badge_outlined,
          title: status == 'APPROVED'
              ? 'Verification complete'
              : status == 'REJECTED'
              ? 'Documents need attention'
              : status == 'PENDING'
              ? 'Documents under review'
              : 'Verify your identity',
          message: reviewNote?.isNotEmpty == true
              ? reviewNote!
              : status == 'PENDING'
              ? 'Your documents are being checked manually. No further action is required right now.'
              : status == 'APPROVED'
              ? 'Your identity verification is complete.'
              : status == 'REJECTED'
              ? 'Review the note and submit corrected documents when ready.'
              : 'Submit the requested details for manual review.',
          status: label,
          nextStep: status == 'APPROVED'
              ? 'No action is required. Keep your profile details current.'
              : status == 'PENDING'
              ? 'The latest result will appear here after review.'
              : status == 'REJECTED'
              ? 'Update the requested documents and submit them again.'
              : 'Start verification and complete each required step.',
          timeline: AppStatusTimeline(
            steps: [
              AppStatusStep(
                label: 'Submitted',
                state: submitted
                    ? AppStatusStepState.done
                    : AppStatusStepState.current,
              ),
              AppStatusStep(
                label: 'Manual review',
                state: decided
                    ? AppStatusStepState.done
                    : status == 'PENDING'
                    ? AppStatusStepState.current
                    : AppStatusStepState.upcoming,
              ),
              AppStatusStep(
                label: 'Result',
                state: decided
                    ? AppStatusStepState.done
                    : AppStatusStepState.upcoming,
              ),
            ],
          ),
          primaryAction: status == 'APPROVED'
              ? null
              : AppStatusAction(label: actionLabel, onPressed: _startKyc),
          secondaryAction: AppStatusAction(
            label: 'Customer Support',
            onPressed: () => showSupportChatPanel(
              context,
              initialMessage: 'I need help with identity verification.',
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_spacing.dart';
import 'app_status_scene.dart';
import 'app_status_timeline.dart';

class KycSubmissionResult extends StatelessWidget {
  const KycSubmissionResult({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.page,
        child: AppStatusScene(
          icon: Icons.fact_check_outlined,
          title: tr('Documents received'),
          message: tr(
            'Your identity documents were submitted successfully and are now under review.',
          ),
          status: tr('Submitted'),
          nextStep: tr(
            'You can continue using available features. The verified result will appear in your profile after review.',
          ),
          timeline: AppStatusTimeline(
            steps: [
              AppStatusStep(
                label: tr('Submitted'),
                description: tr('Documents received securely'),
                state: AppStatusStepState.done,
              ),
              AppStatusStep(
                label: tr('Identity review'),
                description: tr(
                  'Your submitted details are being reviewed',
                ),
                state: AppStatusStepState.current,
              ),
              AppStatusStep(
                label: tr('Result'),
                description: tr('Your profile will show the latest decision'),
              ),
            ],
          ),
          primaryAction: AppStatusAction(label: tr('Done'), onPressed: onDone),
        ),
      ),
    );
  }
}

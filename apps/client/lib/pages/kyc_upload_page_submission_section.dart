part of 'kyc_upload_page.dart';

extension _KycUploadSubmissionSection on _KycUploadPageState {
  Future<void> _submit() async {
    if (fullName.isEmpty || bankDetails == null) {
      _setState(() => errorText = 'Complete your personal and bank details');
      return;
    }
    final file = selectedFile;
    if (selfieFile == null || signatureFile == null) {
      _setState(
        () => errorText = 'Add your selfie and signature before submitting',
      );
      return;
    }

    if (file == null) {
      _setState(() => errorText = 'Choose a KYC file first');
      return;
    }

    if (documentType == 'AADHAAR' && selectedBackFile == null) {
      _setState(() => errorText = 'Add both the front and back of Aadhaar');
      return;
    }

    _setState(() {
      isSubmitting = true;
      errorText = null;
    });

    try {
      await authService.submitKyc(
        accessToken: widget.accessToken,
        documentType: documentType,
        fullName: fullName,
        bankDetails: bankDetails,
        selfieFile: selfieFile!,
        signatureFile: signatureFile!,
        file: documentType == 'AADHAAR'
            ? file.renamed('aadhaar-front-${file.name}')
            : file,
        backFile: documentType == 'AADHAAR'
            ? selectedBackFile!.renamed(
                'aadhaar-back-${selectedBackFile!.name}',
              )
            : null,
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.hourglass_top_rounded,
            size: 56,
            color: Color(0xFF2563EB),
          ),
          content: const SizedBox(
            width: 320,
            child: AppText(
              'Your application has been submitted.\nPlease wait for review.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const AppText('OK'),
            ),
          ],
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _setState(() {
        errorText = clientErrorMessage(
          error,
          fallback: 'Unable to submit KYC. Please try again.',
        );
      });
    } finally {
      if (mounted) {
        _setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  Future<void> _personalDetails() async {
    final controller = TextEditingController(text: fullName);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Personal Details'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: tr('Full name as on your identity document'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 2) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const AppText('Save'),
          ),
        ],
      ),
    );
    if (value != null && mounted) _setState(() => fullName = value);
  }

  Future<void> _bankDetails() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => BankDetailsPage(
          initial: bankDetails ?? {'accountHolder': fullName},
          onContinue: (value) {
            _setState(() => bankDetails = value);
            Navigator.pop(context);
          },
        ),
      ),
    );
    if (mounted && bankDetails != null) _goTo(5);
  }
}

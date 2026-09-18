import '../l10n/app_language.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/auth_layout.dart';

String? internationalPhone(String value, String countryCode) {
  try {
    if (!RegExp(r'^[+\d\s().-]+$').hasMatch(value.trim())) return null;
    var input = value.trim();
    final iso = IsoCode.values.byName(countryCode);
    if (!input.startsWith('+') && iso != IsoCode.IN && input.startsWith('0')) {
      input = input.substring(1);
    }
    if (iso == IsoCode.GB && RegExp(r'^7\d{9}$').hasMatch(input)) {
      return '+44$input';
    }
    final number = PhoneNumber.parse(input, callerCountry: iso);
    return number.isValid() ? number.international : null;
  } catch (_) {
    return null;
  }
}

class InternationalPhoneField extends StatelessWidget {
  const InternationalPhoneField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.errorText,
    this.label = 'Mobile number',
    this.lockCountry = false,
  });

  final TextEditingController controller;
  final Country country;
  final ValueChanged<Country> onCountryChanged;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final String label;
  final bool lockCountry;

  @override
  Widget build(BuildContext context) {
    final codeLabel = '+${country.phoneCode}';
    final prefix = lockCountry
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                codeLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          )
        : TextButton(
            onPressed: !enabled
                ? null
                : () => showCountryPicker(
                    context: context,
                    showPhoneCode: true,
                    favorite: const ['IN'],
                    onSelect: onCountryChanged,
                  ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(country.flagEmoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Flexible(
                  child: AppText(
                    codeLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, size: 16),
              ],
            ),
          );

    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(letterSpacing: 0),
      decoration: InputDecoration(
        labelText: tr(label),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        errorText: errorText,
        errorMaxLines: 4,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 64,
          maxWidth: 140,
          minHeight: AuthLayout.inputHeight,
        ),
        prefixIcon: prefix,
        filled: true,
        fillColor: AuthLayout.pageBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(borderRadius: AppRadius.borderSm),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: const BorderSide(color: AppColors.loss),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: const BorderSide(color: AppColors.loss, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

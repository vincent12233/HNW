import '../l10n/app_language.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/auth_layout.dart';

const _emojiFontFallback = <String>[
  'Apple Color Emoji',
  'Segoe UI Emoji',
  'Noto Color Emoji',
  'Twemoji Mozilla',
];

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

String countrySelectorLabel(Country country) {
  return '${country.name} flag, country code +${country.phoneCode}';
}

class CountryFlagGlyph extends StatelessWidget {
  const CountryFlagGlyph({super.key, required this.country, this.size = 22});

  final Country country;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: countrySelectorLabel(country),
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              country.flagEmoji,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: size * 0.86,
                height: 1,
                leadingDistribution: TextLeadingDistribution.even,
                fontFamilyFallback: _emojiFontFallback,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showAuthCountryPicker({
  required BuildContext context,
  required ValueChanged<Country> onSelect,
}) {
  showCountryPicker(
    context: context,
    showPhoneCode: true,
    favorite: const ['IN'],
    customFlagBuilder: (country) => CountryFlagGlyph(country: country),
    countryListTheme: CountryListThemeData(
      backgroundColor: AuthLayout.pageBackground,
      flagSize: 22,
      borderRadius: AppRadius.sheetTop(),
      textStyle: const TextStyle(
        fontSize: 14,
        letterSpacing: 0,
        color: AppColors.textPrimary,
      ),
      searchTextStyle: const TextStyle(fontSize: 14, letterSpacing: 0),
      emojiFontFamilyFallback: _emojiFontFallback,
    ),
    onSelect: onSelect,
  );
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
    final selectorLabel = countrySelectorLabel(country);
    final prefix = lockCountry
        ? Semantics(
            label: selectorLabel,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.noScaling),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CountryFlagGlyph(country: country),
                      const SizedBox(width: 6),
                      Text(
                        codeLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : Tooltip(
            message: selectorLabel,
            child: TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: !enabled
                  ? null
                  : () => showAuthCountryPicker(
                      context: context,
                      onSelect: onCountryChanged,
                    ),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.noScaling),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CountryFlagGlyph(country: country),
                      const SizedBox(width: 6),
                      Text(
                        codeLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        semanticLabel: selectorLabel,
                      ),
                    ],
                  ),
                ),
              ),
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
          minWidth: 72,
          maxWidth: 148,
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

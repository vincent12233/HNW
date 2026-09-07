import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

String? internationalPhone(String value, String countryCode) {
  try {
    if (!RegExp(r'^[+\d\s().-]+$').hasMatch(value.trim())) return null;
    var input = value.trim();
    final iso = IsoCode.values.byName(countryCode);
    if (!input.startsWith('+') && iso != IsoCode.IN && input.startsWith('0')) input = input.substring(1);
    if (iso == IsoCode.GB && RegExp(r'^7\d{9}$').hasMatch(input)) return '+44$input';
    final number = PhoneNumber.parse(input,
        callerCountry: iso);
    return number.isValid() ? number.international : null;
  } catch (_) {
    return null;
  }
}

class InternationalPhoneField extends StatelessWidget {
  const InternationalPhoneField({super.key, required this.controller,
    required this.country, required this.onCountryChanged, this.enabled = true});
  final TextEditingController controller;
  final Country country;
  final ValueChanged<Country> onCountryChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: TextInputType.phone,
    autofillHints: const [AutofillHints.telephoneNumberNational],
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(
      hintText: 'Mobile Number',
      prefixIconConstraints: const BoxConstraints(minWidth: 104, maxWidth: 132),
      prefixIcon: TextButton(
        onPressed: !enabled ? null : () => showCountryPicker(
          context: context,
          showPhoneCode: true,
          favorite: const ['IN'],
          onSelect: onCountryChanged,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(country.flagEmoji, style: const TextStyle(fontSize: 19)),
          const SizedBox(width: 6),
          Flexible(child: Text('+${country.phoneCode}', style: const TextStyle(fontSize: 12))),
          const Icon(Icons.keyboard_arrow_down, size: 15),
        ]),
      ),
      filled: true,
      fillColor: const Color(0xFFFAFBFE),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFF0F2F6))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFF0F2F6))),
    ),
  );
}

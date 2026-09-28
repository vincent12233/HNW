import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:shared_preferences/shared_preferences.dart';
import 'regional_languages.dart';
import 'hindi_language.dart';

typedef AppLanguageOption = ({String code, String nativeName, String badge});

const appLanguageOptions = <AppLanguageOption>[
  (code: 'en', nativeName: 'English', badge: 'EN'),
  (code: 'hi', nativeName: 'हिन्दी', badge: 'हि'),
  (code: 'ta', nativeName: 'தமிழ்', badge: 'த'),
  (code: 'te', nativeName: 'తెలుగు', badge: 'తె'),
  (code: 'kn', nativeName: 'ಕನ್ನಡ', badge: 'ಕ'),
  (code: 'gu', nativeName: 'ગુજરાતી', badge: 'ગુ'),
  (code: 'ml', nativeName: 'മലയാളം', badge: 'മ'),
];

const supportedAppLanguageCodes = {'en', 'hi', 'ta', 'te', 'kn', 'gu', 'ml'};

String appLanguageName(String code) {
  for (final option in appLanguageOptions) {
    if (option.code == code) return option.nativeName;
  }
  return 'English';
}

class AppLanguage extends ChangeNotifier {
  static final instance = AppLanguage();
  String code = 'en';
  Map<String, String> _remoteCopy = const {};

  String? remoteCopy(String source) => _remoteCopy[source];

  void replaceRemoteCopy(Map<String, String> value) {
    if (mapEquals(_remoteCopy, value)) return;
    _remoteCopy = Map.unmodifiable(value);
    notifyListeners();
  }

  Future<void> load() async {
    final saved = (await SharedPreferences.getInstance()).getString(
      'app_language',
    );
    code = supportedAppLanguageCodes.contains(saved) ? saved! : 'en';
  }

  Future<void> select(String value) async {
    if (!supportedAppLanguageCodes.contains(value)) throw ArgumentError(value);
    final saved = await (await SharedPreferences.getInstance()).setString(
      'app_language',
      value,
    );
    if (!saved) throw StateError('Unable to save language');
    if (code != value) _remoteCopy = const {};
    code = value;
    notifyListeners();
  }
}

// Exact display aliases preserve API values and existing translation keys.
const professionalTerms = <String, String>{
  'Client Tier': 'Membership Tier',
  'Member Since': 'Account Opened',
  'STANDARD': 'Standard',
  'SILVER': 'Silver',
  'GOLD': 'Gold',
  'PLATINUM': 'Platinum',
  'Transaction PIN': 'Withdrawal PIN',
  'Personal Information': 'Personal Details',
  'Change Password': 'Change Login Password',
  'Funds Ledger': 'Account Ledger',
  'Open Holdings': 'Current Holdings',
  'Total Holdings Value': 'Holdings Market Value',
  'Trading Positions Value': 'Positions Market Value',
  'Total Portfolio': 'Portfolio Value',
  'Used Margin': 'Margin Used',
  'Today\'s P&L': 'Daily P&L',
  'Total P&L': 'Total Profit & Loss',
  'Inst.': 'Institutional',
  'No stocks available': 'No instruments available',
  'Explore offers': 'View Investment Offers',
  'Help & Support': 'Customer Support',
  'Support & More': 'Support & Legal',
  'Login to continue': 'Sign in to your account',
  'Login': 'Sign In',
  'Logout': 'Sign Out',
  'Change password': 'Change Login Password',
  'Withdrawal Records': 'Withdrawal History',
  'Bank Details': 'Bank Account Details',
  'Client ID': 'Account ID',
  'ACTIVE': 'Active',
  'INACTIVE': 'Inactive',
  'SUSPENDED': 'Suspended',
};

String tr(String value) =>
    AppLanguage.instance.remoteCopy(value) ??
    _localTranslation(AppLanguage.instance.code, value);

String _localTranslation(String code, String value) {
  final alias = professionalTerms[value];
  if (code == 'hi') return hindi[value] ?? hindi[alias] ?? alias ?? value;
  final regional = regionalTranslations[code];
  return regional?[value] ?? regional?[alias] ?? alias ?? value;
}

// Retains const text declarations while reacting to locale changes, including open routes.
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });
  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Text(
      tr(data),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

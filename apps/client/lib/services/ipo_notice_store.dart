import 'package:shared_preferences/shared_preferences.dart';

/// Stores acknowledgement only; never changes subscription or payment state.
class IpoNoticeStore {
  static String _key(String applicationId) =>
      'ipo_allotment_confirmed_v1_$applicationId';

  Future<bool> isConfirmed(String applicationId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key(applicationId)) ?? false;
  }

  Future<void> confirm(String applicationId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key(applicationId), true);
  }
}

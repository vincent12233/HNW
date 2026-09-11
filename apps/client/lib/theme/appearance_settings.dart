import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppearanceSettings extends ChangeNotifier {
  static final instance = AppearanceSettings();
  String value = 'light';
  Future<void> load() async {
    value =
        (await SharedPreferences.getInstance()).getString('app_theme') ??
        'light';
    notifyListeners();
  }

  Future<void> select(String next) async {
    if (!['light', 'highContrast'].contains(next)) return;
    await (await SharedPreferences.getInstance()).setString('app_theme', next);
    value = next;
    notifyListeners();
  }
}

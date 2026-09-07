import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:india_trading_app/services/device_biometrics.dart';
import 'package:india_trading_app/widgets/international_phone_field.dart';
void main() {
  test('international phones use the selected country and preserve explicit prefixes', () {
    expect(internationalPhone('9876543210', 'IN'), '+919876543210');
    expect(internationalPhone('2025550123', 'US'), '+12025550123');
    expect(internationalPhone('07911123456', 'GB'), '+447911123456');
    expect(internationalPhone('13812345678', 'CN'), '+8613812345678');
    expect(internationalPhone('+12025550123', 'IN'), '+12025550123');
    expect(internationalPhone('123', 'IN'), isNull);
  });
  test('no enrollment hides biometric login and iOS displays its actual capability', () {
    expect(DeviceBiometrics.fromCapabilities(TargetPlatform.android, []), isNull);
    expect(DeviceBiometrics.fromCapabilities(TargetPlatform.iOS, [BiometricType.face]), DeviceBiometric.face);
    expect(DeviceBiometrics.fromCapabilities(TargetPlatform.iOS, [BiometricType.fingerprint]), DeviceBiometric.fingerprint);
    expect(DeviceBiometrics.fromCapabilities(TargetPlatform.android, [BiometricType.weak]), isNull);
  });
}

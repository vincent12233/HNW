import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum DeviceBiometric { fingerprint, face }

class DeviceBiometrics {
  static Future<DeviceBiometric?> available() async {
    if (kIsWeb) return null;
    try {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported() || !await auth.canCheckBiometrics) return null;
      if (defaultTargetPlatform == TargetPlatform.android &&
          await const MethodChannel('india_trading/device_capabilities').invokeMethod<bool>('hasFingerprint') != true) return null;
      return fromCapabilities(defaultTargetPlatform, await auth.getAvailableBiometrics());
    } catch (_) {
      return null;
    }
  }

  static DeviceBiometric? fromCapabilities(TargetPlatform platform, List<BiometricType> types) {
    if (platform == TargetPlatform.iOS) {
      if (types.contains(BiometricType.face)) return DeviceBiometric.face;
      if (types.contains(BiometricType.fingerprint)) return DeviceBiometric.fingerprint;
    }
    if (platform == TargetPlatform.android &&
        (types.contains(BiometricType.fingerprint) || types.contains(BiometricType.strong))) {
      return DeviceBiometric.fingerprint;
    }
    return null;
  }
}

package com.indiatrading.india_trading_app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "india_trading/device_capabilities")
            .setMethodCallHandler { call, result ->
                if (call.method == "hasFingerprint") {
                    result.success(packageManager.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT))
                } else result.notImplemented()
            }
    }
}

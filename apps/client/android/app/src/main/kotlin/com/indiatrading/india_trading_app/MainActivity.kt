package com.indiatrading.india_trading_app

import android.content.Intent
import com.salesmartly.chatwidget.api.SalesmartlyChat
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "india_trading/salesmartly")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openChat" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val scriptUrl = arguments?.get("scriptUrl") as? String
                        if (scriptUrl.isNullOrBlank()) {
                            result.error("missing_configuration", "SALESMARTLY_SCRIPT_URL is required", null)
                            return@setMethodCallHandler
                        }
                        startActivity(Intent(this, SaleSmartlyChatActivity::class.java).apply {
                            arguments.forEach { (key, value) ->
                                if (key is String && value is String) putExtra(key, value)
                            }
                        })
                        result.success(null)
                    }
                    "clearUser" -> {
                        SalesmartlyChat.clearUser()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

package com.jamsabsen.jams_absen

import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.jamsabsen/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceInfo" -> {
                        val androidId = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID
                        ) ?: ""

                        val deviceName = "${Build.BRAND} ${Build.MODEL}".trim()
                        val platform = "Android ${Build.VERSION.RELEASE}"
                        val fingerprint = Build.FINGERPRINT

                        result.success(
                            mapOf(
                                "androidId" to androidId,
                                "fingerprint" to fingerprint,
                                "deviceName" to deviceName,
                                "platform" to platform
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

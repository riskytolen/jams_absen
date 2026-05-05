package com.jamsabsen.jams_absen

import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val DEVICE_CHANNEL = "com.jamsabsen/device"
    private val SECURITY_CHANNEL = "com.jamsabsen/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Device info channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
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

        // ── Security channel — anti-fake GPS ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isDeveloperOptionsEnabled" -> {
                        val enabled = try {
                            Settings.Global.getInt(
                                contentResolver,
                                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                                0
                            ) != 0
                        } catch (e: Exception) {
                            false
                        }
                        result.success(enabled)
                    }

                    "isMockLocationEnabled" -> {
                        // Hanya cek apakah mock location SEDANG aktif saat ini.
                        // Tidak menggunakan getLastKnownLocation karena bisa return
                        // lokasi lama dari saat fake GPS masih aktif.
                        val enabled = try {
                            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                                @Suppress("DEPRECATION")
                                Settings.Secure.getString(
                                    contentResolver,
                                    Settings.Secure.ALLOW_MOCK_LOCATION
                                ) == "1"
                            } else {
                                // Android 6+: kita tidak bisa reliably cek dari native
                                // tanpa request location baru. Serahkan ke Dart layer
                                // yang mengecek Position.isMocked pada reading baru.
                                false
                            }
                        } catch (e: Exception) {
                            false
                        }
                        result.success(enabled)
                    }

                    "isDeviceRooted" -> {
                        result.success(checkRoot())
                    }

                    "getInstalledMockApps" -> {
                        result.success(detectMockLocationApps())
                    }

                    "getSecurityStatus" -> {
                        val devOptions = try {
                            Settings.Global.getInt(
                                contentResolver,
                                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                                0
                            ) != 0
                        } catch (e: Exception) { false }

                        val isRooted = checkRoot()
                        val mockApps = detectMockLocationApps()
                        val isEmulator = checkEmulator()

                        result.success(
                            mapOf(
                                "developerOptionsEnabled" to devOptions,
                                "isRooted" to isRooted,
                                "isEmulator" to isEmulator,
                                "mockAppsInstalled" to mockApps,
                                "mockAppsCount" to mockApps.size,
                                "sdkVersion" to Build.VERSION.SDK_INT,
                                "brand" to Build.BRAND,
                                "model" to Build.MODEL,
                                "fingerprint" to Build.FINGERPRINT
                            )
                        )
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /// Check if device is rooted.
    private fun checkRoot(): Boolean {
        // Method 1: Check common root paths
        val rootPaths = arrayOf(
            "/system/app/Superuser.apk",
            "/system/xbin/su",
            "/system/bin/su",
            "/sbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/data/local/su",
            "/su/bin/su",
            "/system/bin/.ext/.su",
            "/system/usr/we-need-root/su-backup",
            "/system/app/Kinguser.apk",
            "/system/app/KingoUser.apk",
            "/system/xbin/daemonsu",
            "/system/xbin/busybox",
            "/system/etc/init.d/99telecominfra",
            "/system/app/Magisk.apk",
        )

        for (path in rootPaths) {
            if (File(path).exists()) return true
        }

        // Method 2: Check build tags
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) return true

        // Method 3: Try executing su
        try {
            val process = Runtime.getRuntime().exec(arrayOf("/system/xbin/which", "su"))
            val result = process.inputStream.bufferedReader().readText()
            if (result.isNotEmpty()) return true
        } catch (_: Exception) {}

        // Method 4: Check for Magisk
        try {
            val pm = packageManager
            pm.getPackageInfo("com.topjohnwu.magisk", 0)
            return true
        } catch (_: PackageManager.NameNotFoundException) {}

        return false
    }

    /// Detect installed fake GPS / mock location apps.
    private fun detectMockLocationApps(): List<String> {
        val knownMockPackages = listOf(
            "com.lexa.fakegps",
            "com.incorporateapps.fakegps.fre",
            "com.fakegps.mock",
            "com.lkr.fakelocation",
            "com.marlon.floating.fake.location",
            "com.gsmartstudio.fakegps",
            "com.el.fake.gps",
            "com.fake.gps.location",
            "com.evezzon.fakegps",
            "com.divi.fakeGPS",
            "com.rosteam.gpsemulator",
            "com.theappninjas.fakegpsjoystick",
            "com.blogspot.newapphorizons.fakegps",
            "com.ltp.pro.fakelocation",
            "org.hola.gpslocation",
            "com.location.faker",
            "com.zhangshun.fakegps",
            "com.mock.location",
            "ru.gavrikov.mocklocations",
            "com.tencent.fakegps",
        )

        val installedMockApps = mutableListOf<String>()
        val pm = packageManager

        // Check known packages
        for (pkg in knownMockPackages) {
            try {
                pm.getPackageInfo(pkg, 0)
                installedMockApps.add(pkg)
            } catch (_: PackageManager.NameNotFoundException) {}
        }

        // Check apps with mock location permission
        try {
            val installedApps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
            for (app in installedApps) {
                // Skip system apps and our own app
                if (app.flags and ApplicationInfo.FLAG_SYSTEM != 0) continue
                if (app.packageName == packageName) continue

                try {
                    val pkgInfo = pm.getPackageInfo(app.packageName, PackageManager.GET_PERMISSIONS)
                    val permissions = pkgInfo.requestedPermissions ?: continue
                    if (permissions.contains("android.permission.ACCESS_MOCK_LOCATION")) {
                        if (!installedMockApps.contains(app.packageName)) {
                            installedMockApps.add(app.packageName)
                        }
                    }
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}

        return installedMockApps
    }

    /// Check if running on emulator.
    private fun checkEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.BRAND.startsWith("generic")
                || Build.DEVICE.startsWith("generic")
                || "google_sdk" == Build.PRODUCT
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu")
                || Build.PRODUCT.contains("sdk")
                || Build.PRODUCT.contains("emulator")
                || Build.PRODUCT.contains("simulator"))
    }
}

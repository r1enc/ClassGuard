package com.r1enc.classguard.classguard

import android.app.AppOpsManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.media.AudioManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Base64
import android.widget.Toast
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {
    private val AUDIO_CHANNEL = "classguard/audio"
    private val APPLOCK_CHANNEL = "com.classguard/applock"
    private val APPINFO_CHANNEL = "com.classguard/app_info"
// Native communication bridge between Flutter and Android system APIs.
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "muteVolume") {
                val audioManager = applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val notificationManager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

                try {
                    if (notificationManager.isNotificationPolicyAccessGranted) {
                        audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                        result.success("Device Muted!")
                    } else {
                        val intent = Intent(android.provider.Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        applicationContext.startActivity(intent)
                        result.error("PERMISSION_DENIED", "Redirected to Settings.", null)
                    }
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APPLOCK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsagePermission" -> result.success(hasUsageStatsPermission())
                "requestUsagePermission" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(true)
                }
                "checkOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this@MainActivity))
                    } else {
                        result.success(true)
                    }
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        if (!Settings.canDrawOverlays(this@MainActivity)) {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        }
                    }
                    result.success(true)
                }
                "checkAccessibilityPermission" -> {
                    result.success(isAccessibilityServiceEnabled(this@MainActivity, AppLockService::class.java))
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }
                "checkBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    } else {
                        result.success(true)
                    }
                }
                "requestBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                            intent.data = android.net.Uri.parse("package:$packageName")
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        }
                    }
                    result.success(true)
                }
                // Manufacturer-specific autostart settings to improve background service reliability.
                "requestAutoStartPermission" -> {
                    val intent = Intent()
                    val manufacturer = android.os.Build.MANUFACTURER.lowercase()
                    try {
                        when {
                            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco") -> intent.component = android.content.ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                            manufacturer.contains("oppo") || manufacturer.contains("realme") -> intent.component = android.content.ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                            manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> intent.component = android.content.ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                            manufacturer.contains("samsung") -> intent.component = android.content.ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")
                            manufacturer.contains("huawei") || manufacturer.contains("honor") -> intent.component = android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
                            manufacturer.contains("asus") -> intent.component = android.content.ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.entry.FunctionActivity")
                            manufacturer.contains("infinix") || manufacturer.contains("tecno") || manufacturer.contains("itel") -> intent.component = android.content.ComponentName("com.transsion.phonemanager", "com.itel.autobootmanager.activity.AutoBootMgrActivity")
                            else -> {
                                intent.action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                                intent.data = android.net.Uri.parse("package:$packageName")
                            }
                        }
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        fallbackIntent.data = android.net.Uri.parse("package:$packageName")
                        fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(fallbackIntent)
                        result.success(false)
                    }
                }
                "triggerEmergencyPopup" -> {
                    Toast.makeText(
                        applicationContext,
                        "WARNING: CLASSGUARD SECURITY PERMISSIONS DISABLED!",
                        Toast.LENGTH_LONG
                    ).show()

                    val popupIntent = Intent(this@MainActivity, SilentPopupActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    try {
                        startActivity(popupIntent)
                    } catch (e: Exception) {}
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APPINFO_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInstalledApps") {
                Thread {
                    val apps = getInstalledApps()
                    runOnUiThread { result.success(apps) }
                }.start()
            } else {
                result.notImplemented()
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isAccessibilityServiceEnabled(ctx: Context, service: Class<*>): Boolean {
        val am = ctx.getSystemService(Context.ACCESSIBILITY_SERVICE) as android.view.accessibility.AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        for (enabledService in enabledServices) {
            val enabledServiceInfo = enabledService.resolveInfo.serviceInfo
            if (enabledServiceInfo.packageName == ctx.packageName && enabledServiceInfo.name == service.name) {
                return true
            }
        }
        return false
    }
// Retrieve installed applications and usage statistics from Android system.
    private fun getInstalledApps(): List<Map<String, String>> {
        val appList = mutableListOf<Map<String, Any>>()
        val pm = packageManager
        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        val hasPermission = hasUsageStatsPermission()
        val usageMap = mutableMapOf<String, Long>()

        if (hasPermission) {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
            val time = System.currentTimeMillis()
            val stats = usm.queryUsageStats(
                android.app.usage.UsageStatsManager.INTERVAL_DAILY,
                time - 1000 * 60 * 60 * 24 * 7,
                time
            )

            if (stats != null) {
                for (usageStats in stats) {
                    val pkg = usageStats.packageName
                    val totalTime = usageStats.totalTimeInForeground
                    usageMap[pkg] = (usageMap[pkg] ?: 0L) + totalTime
                }
            }
        }

        val homeIntent = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_HOME) }
        val launchers = pm.queryIntentActivities(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)
            .map { it.activityInfo.packageName }

        val systemBlacklist = listOf(
            "com.android.settings", "com.android.deskclock", "com.google.android.deskclock",
            "com.sec.android.app.clockpackage", "com.coloros.alarmclock", "com.vivo.alarmclock",
            "com.miui.calculator", "com.android.contacts", "com.google.android.dialer",
            "com.android.incallui", "com.android.providers.downloads.ui"
        )

        for (app in packages) {
            val isLauncher = launchers.contains(app.packageName)
            val isBlacklisted = systemBlacklist.contains(app.packageName)
            val isSelf = app.packageName == packageName
            val hasLaunchIntent = pm.getLaunchIntentForPackage(app.packageName) != null

            if (hasLaunchIntent && !isSelf && !isLauncher && !isBlacklisted) {
                val appName = pm.getApplicationLabel(app).toString()
                val pkgName = app.packageName
                val iconBase64 = getIconAsBase64(app)
                val usageTime = usageMap[pkgName] ?: 0L

                appList.add(mapOf(
                    "name" to appName,
                    "package" to pkgName,
                    "icon" to iconBase64,
                    "usageTime" to usageTime
                ))
            }
        }

        return appList.sortedWith(compareByDescending<Map<String, Any>> { it["usageTime"] as Long }.thenBy { (it["name"] as String).lowercase() })
            .map {
                mapOf(
                    "name" to it["name"] as String,
                    "package" to it["package"] as String,
                    "icon" to it["icon"] as String
                )
            }
    }

    private fun getIconAsBase64(app: ApplicationInfo): String {
        return try {
            val icon = app.loadIcon(packageManager)
            val bitmap = drawableToBitmap(icon)
            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
        } catch (e: Exception) {
            ""
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }
        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 1
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 1
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
}
package com.r1enc.classguard.classguard

import android.accessibilityservice.AccessibilityService
import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast

class AppLockService : AccessibilityService(), SharedPreferences.OnSharedPreferenceChangeListener {

    private lateinit var prefs: SharedPreferences
    private var currentForegroundPackage: String = ""
    private val handler = Handler(Looper.getMainLooper())
    private var isChecking = false

    private val checkRunnable = object : Runnable {
        override fun run() {
            val isAppLockActive = prefs.getBoolean("flutter.isAppLockActive", false)
            val isExamLockActive = prefs.getBoolean("flutter.isExamLockActive", false)

            if (isAppLockActive || isExamLockActive) {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, 0, 0)

                if (!checkOtherPermissions()) {
                    triggerEmergencyPopup()
                }
            }
            checkAutoKick()
            if (isChecking) {
                handler.postDelayed(this, 2000)
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.registerOnSharedPreferenceChangeListener(this)
        Log.d("ClassGuardService", "Accessibility Service Connected")

        val isLockActive = prefs.getBoolean("flutter.isAppLockActive", false)
        val isWarmupActive = prefs.getBoolean("flutter.isWarmupActive", false)
        val isExamLockActive = prefs.getBoolean("flutter.isExamLockActive", false)

        if (isLockActive || isWarmupActive || isExamLockActive) {
            startProtectionService()
        }

        isChecking = true
        handler.post(checkRunnable)
    }

    override fun onSharedPreferenceChanged(sharedPreferences: SharedPreferences?, key: String?) {
        if (key == "flutter.isAppLockActive" || key == "flutter.isWarmupActive" || key == "flutter.isExamLockActive") {
            val isLockActive = sharedPreferences?.getBoolean("flutter.isAppLockActive", false) ?: false
            val isWarmupActive = sharedPreferences?.getBoolean("flutter.isWarmupActive", false) ?: false
            val isExamLockActive = sharedPreferences?.getBoolean("flutter.isExamLockActive", false) ?: false

            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

            if (isLockActive || isWarmupActive || isExamLockActive) {
                startProtectionService()
            } else {
                val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, maxVolume / 2, 0)
                stopProtectionService()
            }

            if (isLockActive || isExamLockActive) {
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, 0, 0)
            }
        }
    }

    // Using your original safe and stable function
    private fun findTextInNode(node: AccessibilityNodeInfo?): List<String> {
        val list = mutableListOf<String>()
        if (node == null) return list
        if (node.text != null) list.add(node.text.toString())
        if (node.contentDescription != null) list.add(node.contentDescription.toString())
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                list.addAll(findTextInNode(child))
                // Intentionally removed recycle() to prevent crashes on newer Android versions
            }
        }
        return list
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            event.packageName?.let { currentForegroundPackage = it.toString() }
        }

        // MAXIMUM UNINSTALL PROTECTION
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {

            val packageName = event.packageName?.toString()?.lowercase() ?: ""

            // Broad detection net: Settings, Installer, PlayStore, and LAUNCHER (Homescreen)
            val isRiskyApp = packageName.contains("setting") ||
                    packageName.contains("install") ||
                    packageName.contains("launcher") ||
                    packageName.contains("home") ||
                    packageName.contains("vending") ||
                    packageName.contains("sec") ||
                    packageName.contains("miui") ||
                    packageName.contains("coloros") ||
                    packageName.contains("iqoo") ||
                    packageName.contains("vivo") ||
                    packageName.contains("huawei")

            if (isRiskyApp) {
                val nodeInfo = event.source
                if (nodeInfo != null) {
                    val textNodes = findTextInNode(nodeInfo)
                    val textContent = textNodes.joinToString(" ").lowercase()
                    // Remove spaces to anticipate "Class Guard" inputs
                    val textNoSpaces = textContent.replace(" ", "")

                    if (textNoSpaces.contains("classguard") &&
                        (textContent.contains("uninstall") || textContent.contains("copot") ||
                                textContent.contains("hapus") || textContent.contains("app info") ||
                                textContent.contains("info aplikasi") || textContent.contains("clear data") ||
                                textContent.contains("force stop") || textContent.contains("paksa berhenti"))) {

                        val isAppLockActive = prefs.getBoolean("flutter.isAppLockActive", false)
                        val isExamLockActive = prefs.getBoolean("flutter.isExamLockActive", false)

                        if (isAppLockActive || isExamLockActive) {
                            Log.d("ClassGuard", "Uninstall attempt blocked from package: $packageName")
                            val intent = Intent(this, LockActivity::class.java).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                putExtra("blocked_package", "System Settings")
                            }
                            startActivity(intent)
                        }
                    }
                }
            }
        }

        checkAutoKick()
    }

    private fun checkAutoKick() {
        val isAppLockActive = prefs.getBoolean("flutter.isAppLockActive", false)
        val isExamLockActive = prefs.getBoolean("flutter.isExamLockActive", false)

        if (!(isAppLockActive || isExamLockActive) || currentForegroundPackage.isEmpty()) return
        if (currentForegroundPackage == packageName) return

        var isBlocked = false

        if (isExamLockActive) {
            isBlocked = true
        } else {
            val blockedAppsStr = prefs.getString("flutter.blockedApps", "") ?: ""
            val blockedAppsList = blockedAppsStr.split(",")

            for (app in blockedAppsList) {
                if (app.isNotEmpty() && currentForegroundPackage.contains(app)) {
                    isBlocked = true
                    break
                }
            }
        }

        if (isBlocked) {
            // Send signal to Flutter for the Live Activity Tracker feature
            try {
                val violationIntent = Intent("com.classguard.VIOLATION")
                violationIntent.putExtra("packageName", currentForegroundPackage)
                sendBroadcast(violationIntent)
            } catch (e: Exception) {}

            if (!isExamLockActive) {
                val tempUnlockUntil = prefs.getLong("flutter.tempUnlockUntil", 0L)
                if (System.currentTimeMillis() < tempUnlockUntil) {
                    return
                }
                if (tempUnlockUntil != 0L) prefs.edit().putLong("flutter.tempUnlockUntil", 0L).apply()

                val allowedApp = prefs.getString("flutter.allowedApp", "") ?: ""
                val allowedUntil = prefs.getLong("flutter.allowedUntil", 0L)

                if (System.currentTimeMillis() < allowedUntil) {
                    if (allowedApp.isEmpty() || allowedApp == "all" || currentForegroundPackage.contains(allowedApp)) {
                        return
                    }
                }

                if (allowedUntil != 0L && System.currentTimeMillis() >= allowedUntil) {
                    prefs.edit().putLong("flutter.allowedUntil", 0L).apply()
                }
            }

            val intent = Intent(this, LockActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("blocked_package", currentForegroundPackage)
            }
            startActivity(intent)
        }
    }

    private fun checkOtherPermissions(): Boolean {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val hasDnd = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) notificationManager.isNotificationPolicyAccessGranted else true

        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        } else {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        }
        val hasUsage = mode == AppOpsManager.MODE_ALLOWED

        val hasOverlay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Settings.canDrawOverlays(this) else true

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val hasBattery = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) pm.isIgnoringBatteryOptimizations(packageName) else true

        return hasDnd && hasUsage && hasOverlay && hasBattery
    }

    private fun triggerEmergencyPopup() {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(applicationContext, "WARNING: CLASSGUARD PERMISSION DISABLED! SECURITY COMPROMISED!", Toast.LENGTH_LONG).show()
        }

        val popupIntent = Intent(this, SilentPopupActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        try {
            startActivity(popupIntent)
        } catch (e: Exception) {
            Log.e("ClassGuard", "Failed to start activity: " + e.message)
        }
    }

    override fun onUnbind(intent: Intent?): Boolean {
        val isAppLockActive = prefs.getBoolean("flutter.isAppLockActive", false)
        val isExamLockActive = prefs.getBoolean("flutter.isExamLockActive", false)

        if (isAppLockActive || isExamLockActive) {
            Handler(Looper.getMainLooper()).post {
                Toast.makeText(applicationContext, "WARNING: CLASSGUARD ACCESSIBILITY REVOKED!", Toast.LENGTH_LONG).show()
            }
            triggerEmergencyPopup()
        }
        return super.onUnbind(intent)
    }

    private fun startProtectionService() {
        val serviceIntent = Intent(this, ProtectionService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun stopProtectionService() {
        val serviceIntent = Intent(this, ProtectionService::class.java)
        stopService(serviceIntent)
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        isChecking = false
        handler.removeCallbacks(checkRunnable)
        prefs.unregisterOnSharedPreferenceChangeListener(this)
    }
}
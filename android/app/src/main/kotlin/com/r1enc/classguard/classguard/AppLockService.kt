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
import android.widget.Toast

class AppLockService : AccessibilityService(), SharedPreferences.OnSharedPreferenceChangeListener {

    private lateinit var prefs: SharedPreferences
    private var currentForegroundPackage: String = ""
    private val handler = Handler(Looper.getMainLooper())
    private var isChecking = false

    // Continuously verify protection state and monitor critical permissions.
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

    // Start persistent protection service when focus mode, warmup, or exam becomes active.
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

    // React to realtime protection state changes from Flutter SharedPreferences.
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

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            event.packageName?.let { currentForegroundPackage = it.toString() }
        }

        checkAutoKick()
    }

    // Automatically redirect blocked apps into secure lock screen activity.
    private fun checkAutoKick() {
        val isAppLockActive = prefs.getBoolean("flutter.isAppLockActive", false)
        val isExamLockActive = prefs.getBoolean("flutter.isExamLockActive", false)
        
        if (!(isAppLockActive || isExamLockActive) || currentForegroundPackage.isEmpty()) return
        
        // NEVER BLOCK CLASSGUARD ITSELF
        if (currentForegroundPackage == packageName) return

        var isBlocked = false

        if (isExamLockActive) {
            // STRICT EXAM LOCKDOWN: Block ALL other packages unconditionally
            isBlocked = true
        } else {
            // NORMAL CLASS LOCKDOWN: Check blocked apps list
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
            // Only allow PIN Bypass / Allowance Time if NOT in Exam Mode
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
            Toast.makeText(
                applicationContext,
                "WARNING: CLASSGUARD PERMISSION DISABLED! SECURITY COMPROMISED!",
                Toast.LENGTH_LONG
            ).show()
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
                Toast.makeText(
                    applicationContext,
                    "WARNING: CLASSGUARD ACCESSIBILITY REVOKED!",
                    Toast.LENGTH_LONG
                ).show()
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
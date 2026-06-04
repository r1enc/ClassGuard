package com.r1enc.classguard.classguard

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat

class ProtectionService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var isMonitoring = false
    private lateinit var prefs: SharedPreferences

    //---------------------
    // MONITORING RUNNABLE
    //---------------------
    // Monitor continuously at 10-second intervals to prevent the OS from terminating the service.
    private val monitorRunnable = object : Runnable {
        override fun run() {
            if (isMonitoring) {
                val isAppLockActive = prefs.getBoolean("flutter.isAppLockActive", false)
                val isWarmupActive = prefs.getBoolean("flutter.isWarmupActive", false)
                val isExamLockActive = prefs.getBoolean("flutter.isExamLockActive", false)

                // Terminate the service automatically if all protection modes are inactive.
                if (!isAppLockActive && !isWarmupActive && !isExamLockActive) {
                    stopSelf()
                    return
                }

                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val launchIntent = Intent(this@ProtectionService, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(this@ProtectionService, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

                val titleText = if (isExamLockActive) "Exam Mode Active" else if (isAppLockActive) "ClassGuard is Active" else "ClassGuard Warming Up"
                val contentText = if (isExamLockActive) "Exam in progress. App Lock is active." else if (isAppLockActive) "Focus mode is running. App Lock is active." else "Preparing focus mode for upcoming class..."

                val notification = NotificationCompat.Builder(this@ProtectionService, "classguard_protection")
                    .setContentTitle(titleText)
                    .setContentText(contentText)
                    .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
                    .setOngoing(true)
                    .setContentIntent(pendingIntent)
                    .build()

                manager.notify(101, notification)

                // Verify the Accessibility Service status while the class session is ongoing.
                if (!isAccessibilityServiceEnabled(this@ProtectionService, AppLockService::class.java)) {
                    val currentTime = System.currentTimeMillis()
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val isScreenOn = powerManager.isInteractive

                    // Launch the security popup if the screen is currently active.
                    if (isScreenOn) {
                        val lastPopupTime = prefs.getLong("last_popup_time", 0L)
                        // Enforce a 1-minute cooldown to prevent notification spam.
                        if (currentTime - lastPopupTime > 60000) { 
                            prefs.edit().putLong("last_popup_time", currentTime).apply()

                            val popupIntent = Intent(this@ProtectionService, SilentPopupActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                                putExtra("MISSING_PERMISSION", "Accessibility")
                                putExtra("ACTION_SETTINGS", Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            }
                            startActivity(popupIntent)
                        }
                    }
                }

                // 10-second execution delay to comply with strict battery optimizations (e.g., Vivo/Oppo).
                handler.postDelayed(this, 10000)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("classguard_protection", "ClassGuard Protection", NotificationManager.IMPORTANCE_LOW)
            channel.setSound(null, null)
            manager.createNotificationChannel(channel)
        }

        val launchIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        val notification = NotificationCompat.Builder(this, "classguard_protection")
            .setContentTitle("ClassGuard is Active")
            .setContentText("Focus mode is running.")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()

        startForeground(101, notification)

        isMonitoring = true
        handler.post(monitorRunnable)

        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        isMonitoring = false
        handler.removeCallbacks(monitorRunnable)
    }

    private fun isAccessibilityServiceEnabled(context: Context, service: Class<*>): Boolean {
        val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as android.view.accessibility.AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        for (enabledService in enabledServices) {
            val enabledServiceInfo = enabledService.resolveInfo.serviceInfo
            if (enabledServiceInfo.packageName == context.packageName && enabledServiceInfo.name == service.name) {
                return true
            }
        }
        return false
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
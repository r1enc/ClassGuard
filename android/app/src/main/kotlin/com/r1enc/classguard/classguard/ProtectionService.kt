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
import androidx.core.app.NotificationCompat

class ProtectionService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var isMonitoring = false
    private lateinit var prefs: SharedPreferences

    //---------------------
    // MONITORING RUNNABLE
    //---------------------
    // Continuously monitor protection state and accessibility service status.
    private val monitorRunnable = object : Runnable {
        override fun run() {
            if (isMonitoring) {
                val isAppLockActive = prefs.getBoolean("flutter.isAppLockActive", false)
                val isWarmupActive = prefs.getBoolean("flutter.isWarmupActive", false)
                val isExamLockActive = prefs.getBoolean("flutter.isExamLockActive", false)
                
                // Keep service alive while focus mode, warmup mode, or exam mode is still active.
                if (!isAppLockActive && !isWarmupActive && !isExamLockActive) {
                    stopSelf()
                    return
                }

                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val launchIntent = Intent(this@ProtectionService, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(this@ProtectionService, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                
                // Dynamically update foreground notification based on current protection state.
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
                // Detect disabled accessibility permission and display emergency recovery popup.
                if (!isAccessibilityServiceEnabled(this@ProtectionService, AppLockService::class.java)) {
                    val lastPopupTime = prefs.getLong("last_popup_time", 0L)
                    val currentTime = System.currentTimeMillis()

                    if (currentTime - lastPopupTime > 60000) {
                        prefs.edit().putLong("last_popup_time", currentTime).apply()
                        val popupIntent = Intent(this@ProtectionService, SilentPopupActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }
                        startActivity(popupIntent)
                    }
                }
                handler.postDelayed(this, 3000)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    }

    //--------------------------
    // FOREGROUND SERVICE SETUP
    //--------------------------
    // Start persistent foreground service to reduce Android background termination.
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("classguard_protection", "ClassGuard Protection", NotificationManager.IMPORTANCE_LOW)
            channel.setSound(null, null)
            manager.createNotificationChannel(channel)
        }

        val isAppLockActive = prefs.getBoolean("flutter.isAppLockActive", false)
        val isExamLockActive = prefs.getBoolean("flutter.isExamLockActive", false)
        
        val titleText = if (isExamLockActive) "Exam Mode Active" else if (isAppLockActive) "ClassGuard is Active" else "ClassGuard Warming Up"
        val contentText = if (isExamLockActive) "Exam in progress. App Lock is active." else if (isAppLockActive) "Focus mode is running. App Lock is active." else "Preparing focus mode for upcoming class..."

        val launchIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        val notification = NotificationCompat.Builder(this, "classguard_protection")
            .setContentTitle(titleText)
            .setContentText(contentText)
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

    //-------------------
    // PERMISSION CHECKS
    //-------------------
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
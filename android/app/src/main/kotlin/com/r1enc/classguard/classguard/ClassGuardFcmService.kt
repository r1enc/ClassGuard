package com.r1enc.classguard.classguard

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

// Handles high-priority FCM warmup messages sent before a scheduled class starts.
class ClassGuardFcmService : FirebaseMessagingService() {

    // Receives FCM data messages and triggers the warmup sequence when a WARMUP action is detected.
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
    super.onMessageReceived(remoteMessage)

    if (remoteMessage.data.isNotEmpty()) {
        val action = remoteMessage.data["action"]

        if (action == "WARMUP") {
            executeWarmupSequence()
        }
    }
}
    // Initializes protection mechanisms before the scheduled session begins.
    private fun executeWarmupSequence() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // Stores a temporary warmup flag so background components know a session is about to start.
        prefs.edit().putBoolean("flutter.isWarmupActive", true).apply()

        // Starts the foreground protection service to prepare silent mode and app locking features.
        val serviceIntent = Intent(this, ProtectionService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }

        // If Accessibility Service is disabled, guide the user to restore required permissions.
        if (!isAccessibilityServiceEnabled(this, AppLockService::class.java)) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager

            // Launches an emergency permission popup immediately when the screen is already active.
            if (powerManager.isInteractive) {
                val wl = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "ClassGuard::FcmPopupWakeLock"
                )
                wl.acquire(3000L)
                try {
                    val popupIntent = Intent(this, SilentPopupActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("MISSING_PERMISSION", "Accessibility")
                        putExtra("ACTION_SETTINGS", Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    }
                    startActivity(popupIntent)
                } catch (e: Exception) {
                    Log.e("ClassGuardFcmService", "Failed to launch popup: ${e.message}")
                } finally {
                    if (wl.isHeld) wl.release()
                }
            } else {
                // Displays a lock-screen warning notification when the device screen is off.
                sendLockscreenWarning()
            }
        }
    }

    // Creates a full-screen emergency notification that redirects users to restore missing permissions.
    private fun sendLockscreenWarning() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "classguard_emergency"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Emergency Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setSound(null, null)
                enableVibration(false)
            }
            manager.createNotificationChannel(channel)
        }

        val popupIntent = Intent(this, SilentPopupActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("MISSING_PERMISSION", "Accessibility")
            putExtra("ACTION_SETTINGS", Settings.ACTION_ACCESSIBILITY_SETTINGS)
        }

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getActivity(this, 1001, popupIntent, pendingIntentFlags)

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Protection Disabled")
            .setContentText("ClassGuard protection is off. Tap to fix.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setFullScreenIntent(pendingIntent, true)
            .setAutoCancel(true)
            .build()

        manager.notify(998, notification)
    }

    // Checks whether the ClassGuard Accessibility Service is currently enabled.
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
}
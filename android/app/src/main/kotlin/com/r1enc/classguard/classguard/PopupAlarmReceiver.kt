package com.r1enc.classguard.classguard

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat

class PopupAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.isWarmupActive", true).apply()

            // Removed startForegroundService() to prevent BackgroundServiceStartNotAllowedException on Android 12+.

            if (!isAccessibilityServiceEnabled(context, AppLockService::class.java)) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager

                if (powerManager.isInteractive) {
                    // SCENARIO A: The screen is currently active. Launch the popup immediately.
                    launchPopup(context)
                } else {
                    // SCENARIO B: The screen is inactive. Deploy a FullScreenIntent to the lockscreen.
                    sendLockscreenWarning(context)
                }
            }
        } catch (e: Exception) {
            Log.e("PopupAlarmReceiver", "Error in receiver: ${e.message}")
        }
    }

    private fun launchPopup(context: Context) {
        val popupIntent = Intent(context, SilentPopupActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("MISSING_PERMISSION", "Accessibility")
            putExtra("ACTION_SETTINGS", Settings.ACTION_ACCESSIBILITY_SETTINGS)
        }
        context.startActivity(popupIntent)
    }

    private fun sendLockscreenWarning(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
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

        val popupIntent = Intent(context, SilentPopupActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("MISSING_PERMISSION", "Accessibility")
            putExtra("ACTION_SETTINGS", Settings.ACTION_ACCESSIBILITY_SETTINGS)
        }

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getActivity(context, 0, popupIntent, pendingIntentFlags)

        val notification = NotificationCompat.Builder(context, channelId)
            .setContentTitle("Protection Disabled")
            .setContentText("ClassGuard protection is off. Tap to fix.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            // CRITICAL FLAG: Automatically triggers the popup when the screen is turned on.
            .setFullScreenIntent(pendingIntent, true)
            .setAutoCancel(true)
            .build()

        manager.notify(999, notification)
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
}
package com.r1enc.classguard.classguard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PopupAlarmReceiver : BroadcastReceiver() {

    //-------------------
    // ALARM RECEIVER
    //-------------------
    // Trigger emergency popup when accessibility protection is disabled.
    override fun onReceive(context: Context, intent: Intent) {
        if (!isAccessibilityServiceEnabled(context, AppLockService::class.java)) {
            val popupIntent = Intent(context, SilentPopupActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            context.startActivity(popupIntent)
        }
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
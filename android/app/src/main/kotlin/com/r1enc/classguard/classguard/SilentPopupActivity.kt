package com.r1enc.classguard.classguard

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.provider.Settings
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.res.ResourcesCompat

class SilentPopupActivity : Activity() {

    //-------------------------
    // UI SETUP & POPUP DIALOG
    //-------------------------
    // Reusable fullscreen monochrome popup for disabled permissions.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
        )

        // Retrieve dynamic permission details from intent
        val missingPermission = intent.getStringExtra("MISSING_PERMISSION") ?: "Core System"
        val settingsAction = intent.getStringExtra("ACTION_SETTINGS") ?: Settings.ACTION_ACCESSIBILITY_SETTINGS

        // Load Custom Fonts from Android Resources (res/font)
        var fontRegular = Typeface.create("sans-serif", Typeface.NORMAL)
        var fontBold = Typeface.create("sans-serif-medium", Typeface.BOLD)
        try {
            val resFontRegular = ResourcesCompat.getFont(this, R.font.montserrat_regular)
            val resFontBold = ResourcesCompat.getFont(this, R.font.montserrat_bold)
            if (resFontRegular != null) fontRegular = resFontRegular
            if (resFontBold != null) fontBold = resFontBold
        } catch (e: Exception) {
            // Proceeding with default system fonts if custom fonts are missing
        }

        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#80000000"))
            setPadding(dpToPx(40), 0, dpToPx(40), 0)
        }

        val dialogView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = dpToPx(16).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        }

        val title = TextView(this).apply {
            text = "Action Required"
            textSize = 18f
            setTextColor(Color.BLACK)
            typeface = fontBold
            gravity = Gravity.CENTER
            setPadding(dpToPx(16), dpToPx(24), dpToPx(16), dpToPx(8))
        }

        val message = TextView(this).apply {
            text = "$missingPermission permission is disabled.\nClassGuard cannot function properly.\nPlease re-enable it to continue."
            textSize = 14f
            setTextColor(Color.BLACK)
            typeface = fontRegular
            gravity = Gravity.CENTER
            setPadding(dpToPx(16), 0, dpToPx(16), dpToPx(24))
        }

        val fixBtn = TextView(this).apply {
            text = "Fix Now"
            textSize = 16f
            setTextColor(Color.WHITE)
            typeface = fontBold
            gravity = Gravity.CENTER

            background = GradientDrawable().apply {
                setColor(Color.BLACK)
                cornerRadius = dpToPx(10).toFloat()
            }

            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dpToPx(48)).apply {
                setMargins(dpToPx(20), 0, dpToPx(20), dpToPx(20))
            }
            isClickable = true

            // Redirect user directly into the specific Android settings page
            setOnClickListener {
                try {
                    val intent = Intent(settingsAction)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                } catch (e: Exception) {
                    val fallback = Intent(Settings.ACTION_SETTINGS)
                    fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(fallback)
                }
                finish()
            }
        }

        dialogView.addView(title)
        dialogView.addView(message)
        dialogView.addView(fixBtn)

        rootLayout.addView(dialogView)
        setContentView(rootLayout)
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }

    // Disable back navigation while security popup is active.
    override fun onBackPressed() {}
}
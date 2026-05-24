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

class SilentPopupActivity : Activity() {

    //-------------------------
    // UI SETUP & POPUP DIALOG
    //-------------------------
    // Fullscreen security popup displayed when critical permissions are disabled.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )

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
            text = "Security Alert"
            textSize = 18f
            setTextColor(Color.BLACK)
            setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL))
            gravity = Gravity.CENTER
            setPadding(dpToPx(16), dpToPx(24), dpToPx(16), dpToPx(8))
        }

        val message = TextView(this).apply {
            text = "Core system permissions are disabled.\nClassGuard cannot function properly.\nPlease re-enable Accessibility."
            textSize = 14f
            setTextColor(Color.parseColor("#333333"))
            setTypeface(Typeface.create("sans-serif", Typeface.NORMAL))
            gravity = Gravity.CENTER
            setPadding(dpToPx(16), 0, dpToPx(16), dpToPx(24))
        }

        val fixBtn = TextView(this).apply {
            text = "Fix Now"
            textSize = 16f
            setTextColor(Color.WHITE)
            setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL))
            gravity = Gravity.CENTER

            background = GradientDrawable().apply {
                setColor(Color.BLACK)
                cornerRadius = dpToPx(10).toFloat()
            }

            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dpToPx(48)).apply {
                setMargins(dpToPx(20), 0, dpToPx(20), dpToPx(20))
            }
            isClickable = true
            // Redirect user directly into Android accessibility settings.
            setOnClickListener {
                val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
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
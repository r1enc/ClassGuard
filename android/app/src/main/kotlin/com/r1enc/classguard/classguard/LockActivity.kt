package com.r1enc.classguard.classguard

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Vibrator
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.res.ResourcesCompat

class LockActivity : Activity() {
    //----------
    // VARIABLES
    //----------
    private var enteredPin = ""
    private lateinit var pinDotsContainer: LinearLayout
    private lateinit var subtitleDisplay: TextView
    private lateinit var prefs: SharedPreferences

    private var correctPin: String = "1234"
    private var allowanceTimeMinutes: Int = 2
    private var wrongAttempts = 0
    private var isCooldown = false

    //-----------------------------
    // ACTIVITY ONCREATE & UI SETUP
    //-----------------------------
    // Secure fullscreen lock screen displayed when blocked applications are opened.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        correctPin = prefs.getString("flutter.securityPIN", "1234") ?: "1234"
        allowanceTimeMinutes = prefs.getLong("flutter.allowanceTime", 1L).toInt()

        val appNameRaw = intent.getStringExtra("blocked_package") ?: "App"
        var appName = appNameRaw
        try {
            val pm: PackageManager = packageManager
            val appInfo = pm.getApplicationInfo(appNameRaw, 0)
            appName = pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            if (appNameRaw.contains("mobile.legends")) appName = "Mobile Legends"
            else if (appNameRaw.contains("whatsapp")) appName = "WhatsApp"
            else if (appNameRaw.contains("instagram")) appName = "Instagram"
            else if (appNameRaw.contains("facebook")) appName = "Facebook"
            else if (appNameRaw.contains("tiktok") || appNameRaw.contains("musically")) appName = "TikTok"
        }

        window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))

        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            window.addFlags(WindowManager.LayoutParams.FLAG_BLUR_BEHIND)
            window.attributes.blurBehindRadius = 60
        }

        var montserratRegular = Typeface.DEFAULT
        var montserratMedium = Typeface.DEFAULT_BOLD
        var montserratBold = Typeface.DEFAULT_BOLD

        try {
            montserratRegular = ResourcesCompat.getFont(this, R.font.montserrat_regular) ?: Typeface.DEFAULT
            montserratMedium = ResourcesCompat.getFont(this, R.font.montserrat_medium) ?: Typeface.DEFAULT_BOLD
            montserratBold = ResourcesCompat.getFont(this, R.font.montserrat_bold) ?: Typeface.DEFAULT_BOLD
        } catch (e: Exception) {
        }

        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#4D000000"))
        }

        val cardLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dpToPx(24), dpToPx(40), dpToPx(24), dpToPx(40))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#F2FFFFFF"))
                cornerRadius = dpToPx(24).toFloat()
                setStroke(dpToPx(1), Color.parseColor("#E0E0E0"))
            }
            layoutParams = LinearLayout.LayoutParams(
                (resources.displayMetrics.widthPixels * 0.85).toInt(),
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        val title = TextView(this).apply {
            text = "App Locked"
            setTextColor(Color.BLACK)
            textSize = 22f
            typeface = montserratBold
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dpToPx(4))
        }

        subtitleDisplay = TextView(this).apply {
            text = "" // DIKOSONGIN BIAR AESTHETIC
            setTextColor(Color.parseColor("#555555"))
            textSize = 14f
            typeface = montserratRegular
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dpToPx(32))
        }

        cardLayout.addView(title)
        cardLayout.addView(subtitleDisplay)

        pinDotsContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dpToPx(40))
        }
        updatePinDots()
        cardLayout.addView(pinDotsContainer)

        val numpadContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }

        val rows = listOf(
            listOf("1", "2", "3"),
            listOf("4", "5", "6"),
            listOf("7", "8", "9"),
            listOf("Exit", "0", "Del")
        )

        for (row in rows) {
            val rowLayout = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
            }
            for (btnText in row) {
                val btn = TextView(this).apply {
                    text = btnText
                    typeface = montserratMedium
                    gravity = Gravity.CENTER

                    val btnSize = dpToPx(70)
                    layoutParams = LinearLayout.LayoutParams(btnSize, btnSize).apply {
                        setMargins(dpToPx(8), dpToPx(8), dpToPx(8), dpToPx(8))
                    }

                    if (btnText == "Exit" || btnText == "Del") {
                        textSize = 16f
                        setTextColor(Color.parseColor("#666666"))
                        setBackgroundColor(Color.TRANSPARENT)
                    } else {
                        textSize = 28f
                        setTextColor(Color.BLACK)
                        background = GradientDrawable().apply {
                            shape = GradientDrawable.OVAL
                            setColor(Color.parseColor("#0D000000"))
                        }
                    }

                    isClickable = true
                    setOnClickListener { handleBtnClick(btnText) }
                }
                rowLayout.addView(btn)
            }
            numpadContainer.addView(rowLayout)
        }

        cardLayout.addView(numpadContainer)
        rootLayout.addView(cardLayout)
        setContentView(rootLayout)
    }

    //-------------
    // NUMPAD LOGIC
    //-------------
    private fun handleBtnClick(value: String) {
        if (isCooldown) return

        when (value) {
            "Exit" -> {
                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(homeIntent)
                finish()
            }
            "Del" -> {
                if (enteredPin.isNotEmpty()) {
                    enteredPin = enteredPin.dropLast(1)
                    updatePinDots()
                }
            }
            else -> {
                if (enteredPin.length < 4) {
                    enteredPin += value
                    updatePinDots()
                    if (enteredPin.length == 4) verifyPin()
                }
            }
        }
    }

    private fun updatePinDots() {
        pinDotsContainer.removeAllViews()
        for (i in 0 until 4) {
            val dot = View(this).apply {
                val size = dpToPx(16)
                layoutParams = LinearLayout.LayoutParams(size, size).apply {
                    setMargins(dpToPx(12), 0, dpToPx(12), 0)
                }
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    if (i < enteredPin.length) {
                        setColor(Color.BLACK)
                    } else {
                        setColor(Color.TRANSPARENT)
                        setStroke(dpToPx(2), Color.parseColor("#33000000"))
                    }
                }
            }
            pinDotsContainer.addView(dot)
        }
    }

    //----------------------------
    // PIN VERIFICATION & COOLDOWN
    //----------------------------
    private fun verifyPin() {
        if (enteredPin == correctPin) {
            Toast.makeText(this, "Access Granted for $allowanceTimeMinutes Minutes", Toast.LENGTH_LONG).show()

            val unlockDurationMillis = allowanceTimeMinutes * 60 * 1000L
            val unlockTime = System.currentTimeMillis() + unlockDurationMillis
            prefs.edit().putLong("flutter.tempUnlockUntil", unlockTime).apply()

            finish()
        } else {
            wrongAttempts++
            enteredPin = ""
            updatePinDots()

            if (wrongAttempts >= 3) {
                startCooldown()
            } else {
                Toast.makeText(this, "Incorrect PIN", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun startCooldown() {
        isCooldown = true

        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(android.os.VibrationEffect.createOneShot(500, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            vibrator.vibrate(500)
        }

        subtitleDisplay.setTextColor(Color.parseColor("#D32F2F"))
        var timeLeft = 10

        val handler = Handler(Looper.getMainLooper())
        val runnable = object : Runnable {
            override fun run() {
                if (timeLeft > 0) {
                    subtitleDisplay.text = "Too many attempts.\nLocked for ${timeLeft}s"
                    timeLeft--
                    handler.postDelayed(this, 1000)
                } else {
                    isCooldown = false
                    wrongAttempts = 0
                    subtitleDisplay.text = "" 
                    subtitleDisplay.setTextColor(Color.parseColor("#555555"))
                }
            }
        }
        handler.post(runnable)
    }

    override fun onBackPressed() {}

    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}
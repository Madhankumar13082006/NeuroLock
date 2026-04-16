package com.impulsecontrol

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.CountDownTimer
import android.view.View
import android.view.WindowManager
import android.view.animation.PathInterpolator
import android.widget.TextView

class EmotionalInterruptionActivity : Activity() {

    private var timer: CountDownTimer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Full-screen, no interruptions, no user interaction needed.
        window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION

        setContentView(R.layout.activity_emotional_interruption)

        val root = findViewById<View>(R.id.emotional_root)
        val countdown = findViewById<TextView>(R.id.emotional_countdown)
        val breathing = findViewById<BreathingCircleView>(R.id.emotional_breathing_circle)

        // Soft entrance.
        root.alpha = 0f
        root.animate()
            .alpha(1f)
            .setDuration(320)
            .setInterpolator(PathInterpolator(0.2f, 0.0f, 0.0f, 1.0f))
            .start()

        // Subtle breathing guide.
        breathing.startBreathing()

        startCountdown(countdown, root)
    }

    @Deprecated("No-op: interruption screen is non-interactive")
    override fun onBackPressed() {
        // Intentionally no-op.
    }

    private fun startCountdown(countdown: TextView, root: View) {
        fun setTime(secondsLeft: Int) {
            countdown.text = String.format("00:%02d", secondsLeft.coerceIn(0, 99))
        }

        setTime(10)
        countdown.alpha = 0f
        countdown.animate()
            .alpha(1f)
            .setStartDelay(220)
            .setDuration(320)
            .setInterpolator(PathInterpolator(0.2f, 0.0f, 0.0f, 1.0f))
            .start()

        timer?.cancel()
        timer = object : CountDownTimer(10_000L, 1000L) {
            override fun onTick(millisUntilFinished: Long) {
                val seconds = ((millisUntilFinished + 999L) / 1000L).toInt()
                setTime(seconds)
                // Gentle pulse on each tick (no abrupt change).
                countdown.animate().cancel()
                countdown.alpha = 0.55f
                countdown.animate()
                    .alpha(1f)
                    .setDuration(260)
                    .setInterpolator(PathInterpolator(0.2f, 0.0f, 0.0f, 1.0f))
                    .start()
            }

            override fun onFinish() {
                // Soft exit then return to home.
                root.animate().cancel()
                root.animate()
                    .alpha(0f)
                    .setDuration(360)
                    .setInterpolator(PathInterpolator(0.2f, 0.0f, 0.0f, 1.0f))
                    .withEndAction { exitToHomeAndFinish() }
                    .start()
            }
        }.start()
    }

    private fun exitToHomeAndFinish() {
        try {
            startActivity(
                Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_HOME)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION)
            )
        } catch (_: Throwable) {
        }
        finish()
        overridePendingTransition(0, 0)
    }

    override fun onDestroy() {
        timer?.cancel()
        timer = null
        super.onDestroy()
    }
}


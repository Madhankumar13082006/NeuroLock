package com.impulsecontrol

import android.accessibilityservice.AccessibilityService
import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.os.CountDownTimer
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.view.animation.PathInterpolator
import android.widget.TextView

/**
 * Full-screen interruption UI rendered as an accessibility overlay.
 *
 * This is more reliable than launching an Activity on OEM builds that restrict
 * background activity starts during HOME exits.
 */
class EmotionalInterruptionOverlay(private val service: AccessibilityService) {

    private val wm by lazy { service.getSystemService(AccessibilityService.WINDOW_SERVICE) as WindowManager }
    private var view: View? = null
    private var timer: CountDownTimer? = null

    fun show(seconds: Int = 10) {
        // If already showing, restart timer and refresh countdown.
        val existing = view
        if (existing != null) {
            attachCountdown(existing, seconds)
            return
        }

        val v = LayoutInflater.from(service).inflate(R.layout.activity_emotional_interruption, null, false)
        v.alpha = 0f
        v.isClickable = true
        v.isFocusable = true
        v.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO

        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            android.graphics.PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        try {
            wm.addView(v, lp)
            view = v
        } catch (_: Throwable) {
            view = null
            return
        }

        // Start breathing animation (best-effort).
        try {
            v.findViewById<BreathingCircleView>(R.id.emotional_breathing_circle)?.startBreathing()
        } catch (_: Throwable) {
        }

        // Soft fade-in.
        v.animate()
            .alpha(1f)
            .setDuration(320)
            .setInterpolator(PathInterpolator(0.2f, 0.0f, 0.0f, 1.0f))
            .start()

        attachCountdown(v, seconds)
    }

    private fun attachCountdown(v: View, seconds: Int) {
        val countdown = v.findViewById<TextView>(R.id.emotional_countdown) ?: return

        fun setTime(s: Int) {
            countdown.text = String.format("00:%02d", s.coerceIn(0, 99))
        }

        timer?.cancel()
        setTime(seconds)

        countdown.animate().cancel()
        countdown.alpha = 1f

        timer = object : CountDownTimer((seconds * 1000).toLong(), 1000L) {
            override fun onTick(millisUntilFinished: Long) {
                val s = ((millisUntilFinished + 999L) / 1000L).toInt()
                setTime(s)
                // Gentle pulse (no abrupt transitions).
                countdown.animate().cancel()
                countdown.alpha = 0.55f
                countdown.animate()
                    .alpha(1f)
                    .setDuration(260)
                    .setInterpolator(PathInterpolator(0.2f, 0.0f, 0.0f, 1.0f))
                    .start()
            }

            override fun onFinish() {
                fadeOutAndRemove()
            }
        }.start()
    }

    private fun fadeOutAndRemove() {
        val v = view ?: return
        v.animate().cancel()
        v.animate()
            .alpha(0f)
            .setDuration(360)
            .setInterpolator(PathInterpolator(0.2f, 0.0f, 0.0f, 1.0f))
            .setListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    removeNow()
                }
            })
            .start()
    }

    fun removeNow() {
        timer?.cancel()
        timer = null
        val v = view ?: return
        view = null
        try {
            wm.removeView(v)
        } catch (_: Throwable) {
        }
    }
}


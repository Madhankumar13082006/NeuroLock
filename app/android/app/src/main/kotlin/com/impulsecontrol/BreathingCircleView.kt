package com.impulsecontrol

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.util.AttributeSet
import android.view.View
import android.view.animation.PathInterpolator

class BreathingCircleView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    private val circlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }
    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }

    private var breathAnimator: ValueAnimator? = null
    private var progress: Float = 0f // 0..1

    fun startBreathing() {
        if (breathAnimator?.isRunning == true) return
        val interp = PathInterpolator(0.2f, 0.0f, 0.0f, 1.0f)
        breathAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 3600L
            repeatMode = ValueAnimator.REVERSE
            repeatCount = ValueAnimator.INFINITE
            interpolator = interp
            addUpdateListener {
                progress = it.animatedValue as Float
                invalidate()
            }
            start()
        }
    }

    override fun onDetachedFromWindow() {
        breathAnimator?.cancel()
        breathAnimator = null
        super.onDetachedFromWindow()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        val cx = w / 2f
        val cy = h / 2f
        val base = (w.coerceAtMost(h) / 2f) * 0.62f
        val r = base * (0.88f + (progress * 0.18f))

        // Glow (soft, tinted).
        val glowR = r * 1.9f
        glowPaint.shader = RadialGradient(
            cx,
            cy,
            glowR,
            intArrayOf(
                0x55B56CFF.toInt(), // soft purple glow center
                0x2287A7FF.toInt(), // subtle blue halo
                0x00000000,
            ),
            floatArrayOf(0f, 0.55f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(cx, cy, glowR, glowPaint)

        // Inner circle (calm, slightly translucent).
        circlePaint.shader = RadialGradient(
            cx,
            cy,
            r,
            intArrayOf(
                0x66FFFFFF.toInt(),
                0x22FFFFFF.toInt(),
                0x00FFFFFF,
            ),
            floatArrayOf(0f, 0.7f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(cx, cy, r, circlePaint)
    }
}


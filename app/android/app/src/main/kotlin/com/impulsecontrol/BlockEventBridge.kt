package com.impulsecontrol

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/**
 * Sends block-detection events from [AppBlockerService] to Flutter on the main thread.
 * Attached when [MainActivity] configures the [MethodChannel].
 */
object BlockEventBridge {

    @Volatile
    private var channel: MethodChannel? = null

    private val main = Handler(Looper.getMainLooper())

    @Volatile
    private var lastEmitKey = ""

    @Volatile
    private var lastEmitAt = 0L

    private const val EMIT_DEBOUNCE_MS = 1_500L

    fun attach(ch: MethodChannel?) {
        channel = ch
    }

    /**
     * Notifies Dart (optional analytics / logging). Debounced to avoid flooding
     * during [TYPE_WINDOW_CONTENT_CHANGED] storms.
     */
    fun emitBlockTriggered(
        packageName: String,
        features: List<String>,
        activityClass: String?,
        eventType: Int,
    ) {
        val key = "$packageName|${features.sorted().joinToString(",")}|$activityClass"
        val now = android.os.SystemClock.uptimeMillis()
        synchronized(this) {
            if (key == lastEmitKey && now - lastEmitAt < EMIT_DEBOUNCE_MS) return
            lastEmitKey = key
            lastEmitAt = now
        }
        val payload = hashMapOf<String, Any>(
            "packageName" to packageName,
            "features" to features,
            "activityClass" to (activityClass ?: ""),
            "eventType" to eventType,
            "timestamp" to System.currentTimeMillis(),
        )
        main.post {
            try {
                channel?.invokeMethod("onBlockTriggered", payload)
            } catch (_: Exception) {
            }
        }
    }
}

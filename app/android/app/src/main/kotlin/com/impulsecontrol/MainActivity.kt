package com.impulsecontrol

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.impulsecontrol/bridge"
    private var channel: MethodChannel? = null
    private var pendingRoute: String? = null
    private val PREFS = "impulse_control"
    private val KEY_UNLOCK_UNTIL = "unlock_until_ms"
    private val KEY_PIN_SET = "pin_set"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "isAccessibilityEnabled" -> {
                        result.success(AppBlockerService.isEnabled(this@MainActivity))
                    }
                    "setBlockedApps" -> {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        AppBlockerService.updateBlockedApps(packages)
                        result.success(null)
                    }
                    "setUnlockUntilMs" -> {
                        val untilMs = call.argument<Number>("untilMs")?.toLong()
                        getSharedPreferences(PREFS, MODE_PRIVATE)
                            .edit()
                            .putLong(KEY_UNLOCK_UNTIL, untilMs ?: 0L)
                            .apply()
                        result.success(null)
                    }
                    "setPinSet" -> {
                        val isPinSet = call.argument<Boolean>("isPinSet") ?: false
                        getSharedPreferences(PREFS, MODE_PRIVATE)
                            .edit()
                            .putBoolean(KEY_PIN_SET, isPinSet)
                            .apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // If we received a route intent before the channel was ready, deliver it now.
        pendingRoute?.let { route ->
            channel?.invokeMethod("navigate", route)
            pendingRoute = null
        }

        // Also handle the intent that launched the activity.
        handleRouteIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleRouteIntent(intent)
    }

    private fun handleRouteIntent(intent: Intent?) {
        val route = intent?.getStringExtra("route") ?: return
        val ch = channel
        if (ch == null) {
            pendingRoute = route
            return
        }
        ch.invokeMethod("navigate", route)
    }
}

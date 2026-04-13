package com.impulsecontrol

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import org.json.JSONArray
import org.json.JSONObject
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent.ACTION_MAIN
import android.content.Intent.CATEGORY_HOME

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.impulsecontrol/bridge"
    private var channel: MethodChannel? = null
    private var pendingRoute: String? = null
    private val PREFS = "impulse_control"
    private val KEY_UNLOCK_UNTIL = "unlock_until_ms"
    private val KEY_PIN_SET = "pin_set"
    private val KEY_INVITE_ROTATION_PENDING = "invite_rotation_pending"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            BlockEventBridge.attach(this)
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
                        val o = JSONObject()
                        for (p in packages) {
                            o.put(p, JSONArray().put("__full__"))
                        }
                        val json = o.toString()
                        getSharedPreferences(PREFS, MODE_PRIVATE).edit()
                            .putString("blocked_rules_json", json)
                            .commit()
                        AppBlockerService.updateBlockConfigJson(json)
                        result.success(null)
                    }
                    "setBlockConfig" -> {
                        val json = call.argument<String>("rulesJson") ?: "{}"
                        getSharedPreferences(PREFS, MODE_PRIVATE).edit()
                            .putString("blocked_rules_json", json)
                            .commit()
                        AppBlockerService.updateBlockConfigJson(json)
                        result.success(null)
                    }
                    "setUnlockUntilMs" -> {
                        val untilMs = call.argument<Number>("untilMs")?.toLong()
                        getSharedPreferences(PREFS, MODE_PRIVATE)
                            .edit()
                            .putLong(KEY_UNLOCK_UNTIL, untilMs ?: 0L)
                            .commit()
                        result.success(null)
                    }
                    "setPinSet" -> {
                        val isPinSet = call.argument<Boolean>("isPinSet") ?: false
                        getSharedPreferences(PREFS, MODE_PRIVATE)
                            .edit()
                            .putBoolean(KEY_PIN_SET, isPinSet)
                            .commit()
                        result.success(null)
                    }
                    "setInviteRotationPending" -> {
                        val pending = call.argument<Boolean>("pending") ?: false
                        getSharedPreferences(PREFS, MODE_PRIVATE)
                            .edit()
                            .putBoolean(KEY_INVITE_ROTATION_PENDING, pending)
                            .commit()
                        result.success(null)
                    }
                    "isInviteRotationPending" -> {
                        val v = getSharedPreferences(PREFS, MODE_PRIVATE)
                            .getBoolean(KEY_INVITE_ROTATION_PENDING, false)
                        result.success(v)
                    }
                    "goHome" -> {
                        try {
                            startActivity(
                                Intent(ACTION_MAIN)
                                    .addCategory(CATEGORY_HOME)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION),
                            )
                        } catch (_: Exception) {
                        }
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

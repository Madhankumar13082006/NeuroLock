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
    private val KEY_RULES_JSON = "blocked_rules_json"
    private val KEY_SETTINGS_LOCKDOWN_UNTIL_MS = "settings_lockdown_until_ms"
    private fun usageLimitKey(pkg: String) = "usage_limit_min_$pkg"
    private fun usageDayKey(pkg: String) = "usage_day_$pkg"
    private fun usageTodayMsKey(pkg: String) = "usage_today_ms_$pkg"
    private fun featureUsageLimitKey(pkg: String, feature: String) = "feature_usage_limit_min_${pkg}_$feature"
    private fun featureUsageDayKey(pkg: String, feature: String) = "feature_usage_day_${pkg}_$feature"
    private fun featureUsageTodayMsKey(pkg: String, feature: String) = "feature_usage_today_ms_${pkg}_$feature"

    private fun parseRulesOrNull(json: String): JSONObject? {
        if (json.isBlank()) return JSONObject()
        return try {
            JSONObject(json)
        } catch (_: Exception) {
            null
        }
    }

    private fun rulesSimilar(a: JSONObject, b: JSONObject): Boolean {
        // org.json.JSONObject on Android does not consistently expose `similar(...)`
        // across API levels / builds. Use canonical string comparison instead.
        return a.toString() == b.toString()
    }

    private fun tryUpdateRulesJson(
        incomingJson: String,
        result: MethodChannel.Result,
    ) {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val pinSet = prefs.getBoolean(KEY_PIN_SET, false)
        val inviteRotationPending = prefs.getBoolean(KEY_INVITE_ROTATION_PENDING, false)

        val incoming = parseRulesOrNull(incomingJson)
        if (incoming == null) {
            result.error("INVALID_RULES_JSON", "rulesJson is not valid JSON", null)
            return
        }

        val existingRaw = prefs.getString(KEY_RULES_JSON, "{}") ?: "{}"
        val existing = parseRulesOrNull(existingRaw) ?: JSONObject()

        val existingHasRules = existing.length() > 0
        val incomingHasRules = incoming.length() > 0
        val changed = !rulesSimilar(existing, incoming)

        // Once a PIN is set and any blocking rule exists, block config becomes immutable.
        // The only allowed path is "fresh link" / rotation (tracked by inviteRotationPending).
        if (pinSet && existingHasRules && changed && !inviteRotationPending) {
            result.error(
                "CONFIG_LOCKED",
                "Blocked features are locked while PIN is active. Generate a fresh link to change rules.",
                null,
            )
            return
        }

        // Prevent accidental wipes while PIN is set (common during UI edits when an empty config is sent briefly).
        if (pinSet && existingHasRules && !incomingHasRules && !inviteRotationPending) {
            result.error(
                "CONFIG_LOCKED",
                "Cannot clear blocked features while PIN is active. Generate a fresh link to reset.",
                null,
            )
            return
        }

        // Accept update.
        val canonical = incoming.toString()
        prefs.edit()
            .putString(KEY_RULES_JSON, canonical)
            .commit()
        AppBlockerService.updateBlockConfigJson(canonical)
        result.success(null)
    }

    private fun resetLocalProtectionState(result: MethodChannel.Result) {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        try {
            val edit = prefs.edit()
            edit.remove(KEY_UNLOCK_UNTIL)
            edit.remove(KEY_PIN_SET)
            edit.remove(KEY_INVITE_ROTATION_PENDING)
            edit.remove(KEY_RULES_JSON)
            edit.remove(KEY_SETTINGS_LOCKDOWN_UNTIL_MS)

            // Remove usage keys (package + feature limits + day buckets)
            for (k in prefs.all.keys) {
                if (k.startsWith("usage_limit_min_") ||
                    k.startsWith("usage_day_") ||
                    k.startsWith("usage_today_ms_") ||
                    k.startsWith("feature_usage_limit_min_") ||
                    k.startsWith("feature_usage_day_") ||
                    k.startsWith("feature_usage_today_ms_") ||
                    k == "unlock_until_ms" ||
                    k == "pin_set" ||
                    k == "invite_rotation_pending" ||
                    k == "blocked_rules_json" ||
                    k == "settings_lockdown_until_ms"
                ) {
                    edit.remove(k)
                }
            }
            edit.commit()
        } catch (_: Exception) {
            // best-effort; still proceed to reset in-memory rules
        }
        AppBlockerService.updateBlockConfigJson("{}")
        result.success(null)
    }

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
                        tryUpdateRulesJson(o.toString(), result)
                    }
                    "setBlockConfig" -> {
                        val json = call.argument<String>("rulesJson") ?: "{}"
                        tryUpdateRulesJson(json, result)
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
                    "resetLocalProtectionState" -> {
                        resetLocalProtectionState(result)
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
                    "setUsageLimitMinutes" -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        val min = call.argument<Number>("minutes")?.toInt() ?: 0
                        if (pkg.isBlank()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        getSharedPreferences(PREFS, MODE_PRIVATE)
                            .edit()
                            .putInt(usageLimitKey(pkg), min.coerceAtLeast(0))
                            .commit()
                        result.success(null)
                    }
                    "getUsageLimitMinutes" -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        if (pkg.isBlank()) {
                            result.success(0)
                            return@setMethodCallHandler
                        }
                        val v = getSharedPreferences(PREFS, MODE_PRIVATE)
                            .getInt(usageLimitKey(pkg), 0)
                        result.success(v)
                    }
                    "getUsageTodayMinutes" -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        if (pkg.isBlank()) {
                            result.success(0)
                            return@setMethodCallHandler
                        }
                        val p = getSharedPreferences(PREFS, MODE_PRIVATE)
                        // Ensure day rollover is handled even if service hasn't updated yet.
                        val today = AppBlockerService.todayKey()
                        val dayKey = usageDayKey(pkg)
                        val msKey = usageTodayMsKey(pkg)
                        if (p.getString(dayKey, "") != today) {
                            p.edit().putString(dayKey, today).putLong(msKey, 0L).commit()
                        }
                        val ms = p.getLong(msKey, 0L)
                        result.success((ms / 60000L).toInt())
                    }
                    "setFeatureUsageLimitMinutes" -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        val feature = call.argument<String>("featureKey") ?: ""
                        val min = call.argument<Number>("minutes")?.toInt() ?: 0
                        if (pkg.isBlank() || feature.isBlank()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        getSharedPreferences(PREFS, MODE_PRIVATE)
                            .edit()
                            .putInt(featureUsageLimitKey(pkg, feature), min.coerceAtLeast(0))
                            .commit()
                        result.success(null)
                    }
                    "getFeatureUsageLimitMinutes" -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        val feature = call.argument<String>("featureKey") ?: ""
                        if (pkg.isBlank() || feature.isBlank()) {
                            result.success(0)
                            return@setMethodCallHandler
                        }
                        val v = getSharedPreferences(PREFS, MODE_PRIVATE)
                            .getInt(featureUsageLimitKey(pkg, feature), 0)
                        result.success(v)
                    }
                    "getFeatureUsageTodayMinutes" -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        val feature = call.argument<String>("featureKey") ?: ""
                        if (pkg.isBlank() || feature.isBlank()) {
                            result.success(0)
                            return@setMethodCallHandler
                        }
                        val p = getSharedPreferences(PREFS, MODE_PRIVATE)
                        val today = AppBlockerService.todayKey()
                        val dayKey = featureUsageDayKey(pkg, feature)
                        val msKey = featureUsageTodayMsKey(pkg, feature)
                        if (p.getString(dayKey, "") != today) {
                            p.edit().putString(dayKey, today).putLong(msKey, 0L).commit()
                        }
                        val ms = p.getLong(msKey, 0L)
                        result.success((ms / 60000L).toInt())
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

package com.impulsecontrol

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Handler
import android.os.SystemClock
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AppBlockerService : AccessibilityService() {

    companion object {
        private const val PREFS = "impulse_control"
        private const val KEY_RULES_JSON = "blocked_rules_json"
        private const val KEY_INVITE_ROTATION_PENDING = "invite_rotation_pending"
        private const val KEY_SETTINGS_LOCKDOWN_UNTIL_MS = "settings_lockdown_until_ms"
        private const val SETTINGS_LOCKDOWN_MS = 3 * 60 * 1000L
        private const val KEY_USAGE_LIMIT_PREFIX = "usage_limit_min_"
        private const val KEY_USAGE_DAY_PREFIX = "usage_day_"
        private const val KEY_USAGE_TODAY_MS_PREFIX = "usage_today_ms_"
        private const val KEY_FEATURE_USAGE_LIMIT_PREFIX = "feature_usage_limit_min_"
        private const val KEY_FEATURE_USAGE_DAY_PREFIX = "feature_usage_day_"
        private const val KEY_FEATURE_USAGE_TODAY_MS_PREFIX = "feature_usage_today_ms_"

        @Volatile
        private var rulesJson: String = "{}"

        private var lastTriggered = ""
        private var lastTime = 0L
        private var lastYtShortsProbeMs = 0L
        private var lastSocialProbeMs = 0L
        private var lastChromeProbeMs = 0L

        fun todayKey(): String = try {
            SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())
        } catch (_: Exception) {
            Date().time.toString()
        }

        fun updateBlockConfigJson(json: String) {
            rulesJson = json.ifBlank { "{}" }
        }

        /** @deprecated Prefer setBlockConfig from Flutter */
        fun updateBlockedApps(packages: List<String>) {
            val o = JSONObject()
            for (p in packages) o.put(p, JSONArray().put("__full__"))
            rulesJson = o.toString()
        }

        fun loadRulesFromPrefs(ctx: Context) {
            val s = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_RULES_JSON, "{}") ?: "{}"
            rulesJson = s
        }

        fun isEnabled(context: Context): Boolean {
            val prefString = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            return prefString.contains(context.packageName)
        }
    }

    private val prefsName = PREFS
    private val keyUnlockUntil = "unlock_until_ms"
    private val keyPinSet = "pin_set"

    private val overlay by lazy { BlockingOverlay(this) }
    private val emotionalOverlay by lazy { EmotionalInterruptionOverlay(this) }
    private var activePkg: String? = null
    private var activeStartMs: Long = 0L
    private var lastUsageTickMs: Long = 0L
    private val featureLastTickMs: MutableMap<String, Long> = mutableMapOf()
    private var lastLauncherBypassLockMs: Long = 0L
    private var lastClickFastPathMs: Long = 0L

    override fun onServiceConnected() {
        loadRulesFromPrefs(this)
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes =
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                    AccessibilityEvent.TYPE_VIEW_CLICKED   // catches uninstall-button taps
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 10
            flags = flags or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS // multi-window scan
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val pkg = event.packageName?.toString() ?: return
        val prefs = getSharedPreferences(prefsName, MODE_PRIVATE)
        val pinSet = prefs.getBoolean(keyPinSet, false)
        val shouldArmAntiUninstall = pinSet

        // ----------------- CLICK FAST PATH -----------------
        // Uninstall/Confirm tap on a sensitive surface — react BEFORE the
        // dialog commits. This is what catches MIUI/OneUI speed-uninstall.
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED) {
            if (!shouldArmAntiUninstall) return
            val isSensitive = AntiUninstallHeuristics.isSensitiveUninstallSurface(pkg) ||
                AntiUninstallHeuristics.isSettingsLikeSurface(pkg) ||
                AntiUninstallHeuristics.isLauncherSurface(pkg)
            if (!isSensitive) return
            if (!AntiUninstallHeuristics.eventLooksLikeUninstallClick(event)) return

            val now = SystemClock.uptimeMillis()
            if (now - lastClickFastPathMs < 600) return
            if (AntiUninstallHeuristics.uninstallDialogTargetsSelf(this) ||
                AntiUninstallHeuristics.shouldStartSettingsLockdown(this, event)
            ) {
                lastClickFastPathMs = now
                prefs.edit()
                    .putLong(
                        KEY_SETTINGS_LOCKDOWN_UNTIL_MS,
                        System.currentTimeMillis() + SETTINGS_LOCKDOWN_MS
                    ).commit()
                triggerLock(
                    lockTarget = packageName,
                    packageName = pkg,
                    featuresForFlutter = listOf("anti_uninstall_click"),
                    forceHome = true,
                )
            }
            return
        }
        // ---------------------------------------------------

        val unlockUntil = prefs.getLong(keyUnlockUntil, 0L)
        val unlocked = unlockUntil > System.currentTimeMillis()

        // Seed usage tracking
        if (activePkg == null) {
            val now = SystemClock.elapsedRealtime()
            activePkg = pkg
            activeStartMs = now
            lastUsageTickMs = now
        }

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            updateUsageOnWindowChange(prefs, pkg)
        } else {
            tickUsage(prefs, pkg)
        }

        val rules = try { JSONObject(rulesJson) } catch (_: Exception) { JSONObject() }
        val hasRule = hasSupportedReleaseRule(rules, pkg)

        // Settings lockdown — active for 3 min after any detection
        val settingsLockdownUntil = prefs.getLong(KEY_SETTINGS_LOCKDOWN_UNTIL_MS, 0L)
        val settingsLockdownActive =
            shouldArmAntiUninstall && settingsLockdownUntil > System.currentTimeMillis()
        if (settingsLockdownActive && AntiUninstallHeuristics.isSettingsLikeSurface(pkg)) {
            triggerLock(
                lockTarget = "com.android.settings",
                packageName = pkg,
                featuresForFlutter = listOf("settings_lockdown"),
                forceHome = true,
            )
            return
        }

        // Fresh settings lockdown trigger
        val settingsShouldLockDown = shouldArmAntiUninstall &&
            AntiUninstallHeuristics.shouldStartSettingsLockdown(this, event)
        if (settingsShouldLockDown) {
            prefs.edit()
                .putLong(
                    KEY_SETTINGS_LOCKDOWN_UNTIL_MS,
                    System.currentTimeMillis() + SETTINGS_LOCKDOWN_MS
                ).commit()
            triggerLock(
                lockTarget = "com.android.settings",
                packageName = pkg,
                featuresForFlutter = listOf("settings_lockdown_trigger"),
                forceHome = true,
            )
            return
        }

        // Daily usage limit
        if (hasRule && shouldApplyPackageUsageLimit(rules, pkg) &&
            isUsageLimitReached(prefs, pkg)
        ) {
            triggerLock(
                lockTarget = pkg,
                packageName = pkg,
                featuresForFlutter = listOf("usage_limit"),
                forceHome = false,
            )
            return
        }

        // Anti-uninstall general
        val needsAntiUninstallPin = shouldArmAntiUninstall &&
            AntiUninstallHeuristics.shouldArmAntiUninstallForSensitivePackage(this, event, pkg)

        // Launcher drag-to-uninstall / long-press shield
        val launcherBypassDetected = shouldArmAntiUninstall &&
            LauncherUninstallBypassShield.shouldForceLock(
                service = this,
                event = event,
                foregroundPackage = pkg,
            )
        if (launcherBypassDetected) {
            val now = SystemClock.elapsedRealtime()
            if (now - lastLauncherBypassLockMs >= 1200L) {
                lastLauncherBypassLockMs = now
                triggerLock(
                    lockTarget = packageName,
                    packageName = pkg,
                    featuresForFlutter = listOf("anti_uninstall_launcher_bypass"),
                    forceHome = true,
                )
                return
            }
        }

        if (!hasRule && !needsAntiUninstallPin) return

        // Immediate exit for package-installer surfaces targeting us
        if (needsAntiUninstallPin &&
            (AntiUninstallHeuristics.isPackageInstallerSurface(pkg) ||
                pkg == "com.android.vending")
        ) {
            triggerLock(
                lockTarget = packageName,
                packageName = pkg,
                featuresForFlutter = listOf("anti_uninstall_nokkon"),
                forceHome = true,
            )
            return
        }

        if (unlocked) return
        if (hasRule && !shouldBlockPackage(pkg, event, rules)) return

        val featuresForFlutter = when {
            hasRule -> featureListForRules(rules, pkg)
            needsAntiUninstallPin -> listOf("anti_uninstall_nokkon")
            else -> listOf("restricted_surface")
        }
        BlockEventBridge.emitBlockTriggered(
            packageName = pkg,
            features = featuresForFlutter,
            activityClass = event.className?.toString(),
            eventType = event.eventType,
        )

        val lockTarget = if (needsAntiUninstallPin) packageName else pkg
        triggerLock(
            lockTarget = lockTarget,
            packageName = pkg,
            featuresForFlutter = featuresForFlutter,
            forceHome = needsAntiUninstallPin,
        )
    }

    private fun usageLimitKey(pkg: String) = KEY_USAGE_LIMIT_PREFIX + pkg
    private fun usageDayKey(pkg: String) = KEY_USAGE_DAY_PREFIX + pkg
    private fun usageTodayMsKey(pkg: String) = KEY_USAGE_TODAY_MS_PREFIX + pkg
    private fun featureUsageLimitKey(pkg: String, feature: String) =
        KEY_FEATURE_USAGE_LIMIT_PREFIX + pkg + "_" + feature
    private fun featureUsageDayKey(pkg: String, feature: String) =
        KEY_FEATURE_USAGE_DAY_PREFIX + pkg + "_" + feature
    private fun featureUsageTodayMsKey(pkg: String, feature: String) =
        KEY_FEATURE_USAGE_TODAY_MS_PREFIX + pkg + "_" + feature

    private fun isUsageLimitReached(prefs: android.content.SharedPreferences, pkg: String): Boolean {
        val limitMin = prefs.getInt(usageLimitKey(pkg), 0)
        if (limitMin <= 0) return false
        val today = todayKey()
        val dayKey = usageDayKey(pkg)
        val msKey = usageTodayMsKey(pkg)
        if (prefs.getString(dayKey, "") != today) {
            prefs.edit().putString(dayKey, today).putLong(msKey, 0L).commit()
            return false
        }
        val spentMs = prefs.getLong(msKey, 0L)
        val pending = if (activePkg == pkg && lastUsageTickMs > 0L) {
            (SystemClock.elapsedRealtime() - lastUsageTickMs)
                .coerceAtLeast(0L)
                .coerceAtMost(30_000L)
        } else 0L
        return (spentMs + pending) >= limitMin * 60_000L
    }

    private fun updateUsageOnWindowChange(prefs: android.content.SharedPreferences, newPkg: String) {
        val now = SystemClock.elapsedRealtime()
        val prev = activePkg
        if (prev != null && activeStartMs > 0L && prev != newPkg) {
            val delta = (now - activeStartMs).coerceAtLeast(0L).coerceAtMost(60 * 60 * 1000L)
            val today = todayKey()
            val dayKey = usageDayKey(prev)
            val msKey = usageTodayMsKey(prev)
            val edit = prefs.edit()
            if (prefs.getString(dayKey, "") != today) {
                edit.putString(dayKey, today).putLong(msKey, 0L)
            }
            val cur = prefs.getLong(msKey, 0L)
            edit.putLong(msKey, cur + delta).commit()
        }
        activePkg = newPkg
        activeStartMs = now
        lastUsageTickMs = now
    }

    private fun tickUsage(prefs: android.content.SharedPreferences, pkg: String) {
        val curPkg = activePkg
        if (curPkg == null) {
            val now0 = SystemClock.elapsedRealtime()
            activePkg = pkg
            activeStartMs = now0
            lastUsageTickMs = now0
            return
        }
        if (curPkg != pkg) return
        val now = SystemClock.elapsedRealtime()
        val last = lastUsageTickMs
        if (last <= 0L) { lastUsageTickMs = now; return }
        if (now - last < 500L) return
        val delta = (now - last).coerceAtLeast(0L).coerceAtMost(15_000L)
        lastUsageTickMs = now

        val today = todayKey()
        val dayKey = usageDayKey(curPkg)
        val msKey = usageTodayMsKey(curPkg)
        val edit = prefs.edit()
        if (prefs.getString(dayKey, "") != today) {
            edit.putString(dayKey, today).putLong(msKey, 0L)
        }
        val prevMs = prefs.getLong(msKey, 0L)
        edit.putLong(msKey, prevMs + delta).commit()
    }

    private fun triggerLock(
        lockTarget: String,
        packageName: String,
        featuresForFlutter: List<String>,
        forceHome: Boolean,
    ) {
        val now = System.currentTimeMillis()
        if (packageName == lastTriggered && now - lastTime < 2500) return
        lastTriggered = packageName
        lastTime = now

        overlay.show()

        if (forceHome) {
            try { performGlobalAction(GLOBAL_ACTION_HOME) } catch (_: Throwable) { }
            // Double-tap BACK first, then HOME as fallback to close aggressive OEM dialogs
            try { performGlobalAction(GLOBAL_ACTION_BACK) } catch (_: Throwable) { }
        }

        val isUninstallInterruption =
            featuresForFlutter.any { it.startsWith("anti_uninstall") } ||
                featuresForFlutter.any { it.startsWith("settings_lockdown") }

        if (forceHome && isUninstallInterruption) {
            emotionalOverlay.show(10)
        } else {
            val intent = Intent(this, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                putExtra("route", "/lock/$lockTarget")
                putExtra("strict_exit_home", true)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS,
                )
            }
            startActivity(intent)
        }

        val hideDelay = if (forceHome && isUninstallInterruption) 220L else if (forceHome) 1500L else 800L
        overlay.hideDelayed(hideDelay)
    }

    private fun featureListForRules(rules: JSONObject, pkg: String): List<String> {
        if (pkg == FeatureBlockDetector.PKG_CHROME) {
            val out = ArrayList<String>()
            val ytArr = rules.optJSONArray(FeatureBlockDetector.PKG_YOUTUBE)
            if (ytArr != null) for (i in 0 until ytArr.length())
                if (ytArr.optString(i) == "web_shorts") { out.add("web_shorts"); break }
            val igArr = rules.optJSONArray(FeatureBlockDetector.PKG_INSTAGRAM)
            if (igArr != null) for (i in 0 until igArr.length())
                if (igArr.optString(i) == "web_reels") { out.add("web_reels"); break }
            return out
        }
        val arr = rules.optJSONArray(pkg) ?: return emptyList()
        val out = ArrayList<String>()
        for (i in 0 until arr.length()) {
            val s = arr.optString(i, "")
            if (s.isBlank() || s == "__full__") continue
            if (pkg == FeatureBlockDetector.PKG_YOUTUBE && s == "shorts") out.add(s)
            if (pkg == FeatureBlockDetector.PKG_INSTAGRAM &&
                (s == "reels" || s == "explore")) out.add(s)
        }
        return out
    }

    private fun shouldBlockPackage(
        pkg: String, event: AccessibilityEvent, rules: JSONObject,
    ): Boolean {
        if (pkg == FeatureBlockDetector.PKG_CHROME) return shouldBlockChrome(event, rules)
        val arr = rules.optJSONArray(pkg) ?: return false
        if (arr.length() == 0) return false
        val feats = mutableSetOf<String>()
        for (i in 0 until arr.length()) feats.add(arr.optString(i, ""))

        if (pkg == FeatureBlockDetector.PKG_YOUTUBE) {
            if (!feats.contains("shorts")) return false
            val yt = shouldBlockYouTubeShortsOnly(event)
            return yt && shouldEnforceFeatureBlock(getSharedPreferences(prefsName, MODE_PRIVATE), pkg, "shorts")
        }
        if (pkg == FeatureBlockDetector.PKG_INSTAGRAM) {
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
                val t = SystemClock.uptimeMillis()
                if (t - lastSocialProbeMs < 550) return false
                lastSocialProbeMs = t
            }
            val prefs = getSharedPreferences(prefsName, MODE_PRIVATE)
            if (feats.contains("reels") &&
                FeatureBlockDetector.shouldBlockGenericSocial(this, event, setOf("reels"), pkg)
            ) return shouldEnforceFeatureBlock(prefs, pkg, "reels")
            if (feats.contains("explore")) {
                val root = rootInActiveWindow
                if (root != null) {
                    val onExplore = try { ReferenceBlockHeuristics.instagramExploreSurface(root) } catch (_: Exception) { false }
                    try { root.recycle() } catch (_: Exception) {}
                    if (onExplore) return shouldEnforceFeatureBlock(prefs, pkg, "explore")
                }
            }
            return false
        }
        return false
    }

    private fun shouldBlockChrome(event: AccessibilityEvent, rules: JSONObject): Boolean {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            val t = SystemClock.uptimeMillis()
            if (t - lastChromeProbeMs < 550) return false
            lastChromeProbeMs = t
        }
        val ytArr = rules.optJSONArray(FeatureBlockDetector.PKG_YOUTUBE)
        val igArr = rules.optJSONArray(FeatureBlockDetector.PKG_INSTAGRAM)
        val wantYtWebShorts = ytArr != null && (0 until ytArr.length()).any { ytArr.optString(it) == "web_shorts" }
        val wantIgWebReels = igArr != null && (0 until igArr.length()).any { igArr.optString(it) == "web_reels" }
        if (!wantYtWebShorts && !wantIgWebReels) return false
        val root = rootInActiveWindow ?: return false
        return try {
            val prefs = getSharedPreferences(prefsName, MODE_PRIVATE)
            when {
                wantYtWebShorts && ReferenceBlockHeuristics.chromeHasYouTubeShorts(root) ->
                    shouldEnforceFeatureBlock(prefs, FeatureBlockDetector.PKG_YOUTUBE, "web_shorts")
                wantIgWebReels && ReferenceBlockHeuristics.chromeHasInstagramReels(root) ->
                    shouldEnforceFeatureBlock(prefs, FeatureBlockDetector.PKG_INSTAGRAM, "web_reels")
                else -> false
            }
        } finally {
            try { root.recycle() } catch (_: Exception) {}
        }
    }

    private fun shouldApplyPackageUsageLimit(rules: JSONObject, pkg: String): Boolean {
        val arr = rules.optJSONArray(pkg) ?: return false
        if (arr.length() == 0) return false
        val feats = mutableSetOf<String>()
        for (i in 0 until arr.length()) feats.add(arr.optString(i, ""))
        if (pkg == FeatureBlockDetector.PKG_YOUTUBE) return feats.contains("__full__") || feats.contains("videos")
        if (pkg == FeatureBlockDetector.PKG_INSTAGRAM) return feats.contains("__full__") || feats.contains("stories") || feats.contains("messages")
        return false
    }

    private fun hasSupportedReleaseRule(rules: JSONObject, pkg: String): Boolean {
        if (pkg == FeatureBlockDetector.PKG_CHROME) {
            val ytArr = rules.optJSONArray(FeatureBlockDetector.PKG_YOUTUBE)
            if (ytArr != null) {
                for (i in 0 until ytArr.length()) {
                    if (ytArr.optString(i) == "web_shorts") return true
                }
            }
            val igArr = rules.optJSONArray(FeatureBlockDetector.PKG_INSTAGRAM)
            if (igArr != null) {
                for (i in 0 until igArr.length()) {
                    if (igArr.optString(i) == "web_reels") return true
                }
            }
            return false
        }
        if (pkg != FeatureBlockDetector.PKG_YOUTUBE && pkg != FeatureBlockDetector.PKG_INSTAGRAM) return false
        val arr = rules.optJSONArray(pkg) ?: return false
        if (arr.length() == 0) return false
        for (i in 0 until arr.length()) {
            val f = arr.optString(i, "")
            if (pkg == FeatureBlockDetector.PKG_YOUTUBE && f == "shorts") return true
            if (pkg == FeatureBlockDetector.PKG_INSTAGRAM && (f == "reels" || f == "explore")) return true
        }
        return false
    }

    private fun shouldEnforceFeatureBlock(
        prefs: android.content.SharedPreferences, pkg: String, feature: String,
    ): Boolean {
        val limitMin = prefs.getInt(featureUsageLimitKey(pkg, feature), 0)
        if (limitMin <= 0) return true
        val today = todayKey()
        val dayKey = featureUsageDayKey(pkg, feature)
        val msKey = featureUsageTodayMsKey(pkg, feature)
        if (prefs.getString(dayKey, "") != today) {
            prefs.edit().putString(dayKey, today).putLong(msKey, 0L).commit()
            featureLastTickMs.remove("$pkg|$feature")
        }
        val key = "$pkg|$feature"
        val now = SystemClock.elapsedRealtime()
        val last = featureLastTickMs[key]
        featureLastTickMs[key] = now
        val delta = if (last == null) 0L else (now - last).coerceAtLeast(0L).coerceAtMost(15_000L)
        if (delta > 0L) {
            val cur = prefs.getLong(msKey, 0L)
            prefs.edit().putLong(msKey, cur + delta).commit()
        }
        return prefs.getLong(msKey, 0L) >= (limitMin * 60_000L)
    }

    private fun shouldBlockYouTubeShortsOnly(event: AccessibilityEvent): Boolean {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            val t = SystemClock.uptimeMillis()
            if (t - lastYtShortsProbeMs < 700) return false
            lastYtShortsProbeMs = t
        }
        val cls = event.className?.toString()?.lowercase() ?: ""
        if (cls.contains("reel") && (cls.contains("shorts") || cls.contains("watch"))) return true
        if (cls.contains("shorts") && cls.contains("activity")) return true
        val root = rootInActiveWindow ?: return false
        try {
            val nav = readYouTubeBottomNavState(root)
            if (ReferenceBlockHeuristics.youtubeHasReelSurface(root) &&
                (nav.shortsSelected || !nav.homeSelected)
            ) return true
            if (findStrictShortsPlayer(root, 0)) return true
            if (nav.homeSelected && !nav.shortsSelected) return false
            if (nav.shortsSelected) return true
            return false
        } finally { root.recycle() }
    }

    private data class YtBottomNav(val homeSelected: Boolean, val shortsSelected: Boolean)

    private fun readYouTubeBottomNavState(root: AccessibilityNodeInfo?): YtBottomNav {
        if (root == null) return YtBottomNav(false, false)
        var home = false; var shorts = false
        fun walk(n: AccessibilityNodeInfo?, depth: Int) {
            if (n == null || depth > 42) return
            try {
                if (n.isSelected) {
                    val cd = n.contentDescription?.toString()?.lowercase()?.trim() ?: ""
                    val tx = n.text?.toString()?.lowercase()?.trim() ?: ""
                    if (cd == "home" || tx == "home" || (cd.contains("home") && cd.contains("tab"))) home = true
                    if (cd == "shorts" || cd.startsWith("shorts,") || tx == "shorts" ||
                        (cd.contains("shorts") && !cd.contains("shortcut"))) shorts = true
                }
            } catch (_: Exception) { }
            for (i in 0 until n.childCount) walk(n.getChild(i), depth + 1)
        }
        walk(root, 0)
        return YtBottomNav(home, shorts)
    }

    private fun findStrictShortsPlayer(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 42) return false
        try {
            val id = node.viewIdResourceName?.lowercase() ?: ""
            if (looksLikeShortsPlayerId(id)) return true
        } catch (_: Exception) { }
        for (i in 0 until node.childCount) {
            val c = node.getChild(i) ?: continue
            if (findStrictShortsPlayer(c, depth + 1)) return true
        }
        return false
    }

    private fun looksLikeShortsPlayerId(id: String): Boolean {
        val reelOrShorts = id.contains("shorts") || id.contains("reel")
        if (!reelOrShorts) return false
        if (id.contains("shelf") || id.contains("carousel") || id.contains("chip") ||
            id.contains("thumbnail") || id.contains("navigation") || id.contains("tab_bar") ||
            id.contains("avatar")
        ) return false
        return id.contains("player") || id.contains("watch") || id.contains("pager") ||
            id.contains("viewer") || id.contains("surface") || id.contains("watch_frame")
    }

    override fun onInterrupt() {}
}

private class BlockingOverlay(private val service: AccessibilityService) {
    private val wm by lazy { service.getSystemService(Context.WINDOW_SERVICE) as WindowManager }
    private var view: View? = null
    private val handler by lazy { Handler(service.mainLooper) }

    fun show() {
        if (view != null) return
        val v = View(service).apply {
            setBackgroundColor(0xFF000000.toInt())
            isClickable = true
            isFocusable = true
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP or Gravity.START }
        try { wm.addView(v, lp); view = v } catch (_: Throwable) { view = null }
    }

    fun hide() {
        val v = view ?: return
        view = null
        try { wm.removeView(v) } catch (_: Throwable) { }
    }

    fun hideDelayed(ms: Long) {
        handler.removeCallbacksAndMessages(null)
        handler.postDelayed({ hide() }, ms)
    }
}

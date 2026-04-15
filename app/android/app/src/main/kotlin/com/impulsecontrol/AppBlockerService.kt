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

        fun todayKey(): String {
            return try {
                SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())
            } catch (_: Exception) {
                Date().time.toString()
            }
        }

        fun updateBlockConfigJson(json: String) {
            rulesJson = json.ifBlank { "{}" }
        }

        /** @deprecated Prefer setBlockConfig from Flutter */
        fun updateBlockedApps(packages: List<String>) {
            val o = JSONObject()
            for (p in packages) {
                o.put(p, JSONArray().put("__full__"))
            }
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
    private var activePkg: String? = null
    private var activeStartMs: Long = 0L
    private var lastUsageTickMs: Long = 0L
    private val featureLastTickMs: MutableMap<String, Long> = mutableMapOf()
    private var lastLauncherBypassLockMs: Long = 0L

    override fun onServiceConnected() {
        loadRulesFromPrefs(this)
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes =
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            // Reduce latency so we can cover Settings/blocked apps quickly.
            notificationTimeout = 10
            // Needed for findAccessibilityNodeInfosByViewId (reference: xblockit BlockAccessibility)
            flags = flags or AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val pkg = event.packageName?.toString() ?: return
        val prefs = getSharedPreferences(prefsName, MODE_PRIVATE)
        val unlockUntil = prefs.getLong(keyUnlockUntil, 0L)
        val pinSet = prefs.getBoolean(keyPinSet, false)
        val inviteRotationPending = prefs.getBoolean(KEY_INVITE_ROTATION_PENDING, false)
        val unlocked = unlockUntil > System.currentTimeMillis()

        // Ensure we always have a starting point for usage tracking even if some OEM builds
        // don't deliver a window-state change early enough (e.g. Shorts).
        if (activePkg == null) {
            val now = SystemClock.elapsedRealtime()
            activePkg = pkg
            activeStartMs = now
            lastUsageTickMs = now
        }

        // Track foreground time (daily usage).
        // Some apps (especially YouTube Shorts) may not trigger window-state transitions
        // frequently, so we also tick on other accessibility events while the same package
        // stays in foreground.
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            updateUsageOnWindowChange(prefs, pkg)
        } else {
            tickUsage(prefs, pkg)
        }

        val rules = try {
            JSONObject(rulesJson)
        } catch (_: Exception) {
            JSONObject()
        }
        val hasAnyConfiguredRule = rules.length() > 0
        val shouldArmAntiUninstall = pinSet || inviteRotationPending || hasAnyConfiguredRule
        val hasRule = hasSupportedReleaseRule(rules, pkg)

        // Strict Settings lockdown: while active, Settings should never be visible.
        val settingsLockdownUntil = prefs.getLong(KEY_SETTINGS_LOCKDOWN_UNTIL_MS, 0L)
        val settingsLockdownActive = settingsLockdownUntil > System.currentTimeMillis()
        if (settingsLockdownActive && AntiUninstallHeuristics.isSettingsLikeSurface(pkg)) {
            triggerLock(
                lockTarget = "com.android.settings",
                packageName = pkg,
                featuresForFlutter = listOf("settings_lockdown"),
                forceHome = true,
            )
            return
        }

        // Settings strict protection (AppLock style):
        // The moment we detect the user is on NeuroLock's App Info / uninstall-style surface
        // inside Settings, we kick them out and lock Settings for 3 minutes (refreshed on each hit).
        //
        // This prevents the iterative bypass: close PIN -> tap one button -> close PIN -> tap again.
        //
        // IMPORTANT: This must remain active even during the 1-hour "delay unlock" window.
        val settingsShouldLockDown = shouldArmAntiUninstall &&
            AntiUninstallHeuristics.shouldStartSettingsLockdown(this, event)
        if (settingsShouldLockDown) {
            prefs.edit()
                .putLong(KEY_SETTINGS_LOCKDOWN_UNTIL_MS, System.currentTimeMillis() + SETTINGS_LOCKDOWN_MS)
                .commit()
            triggerLock(
                lockTarget = "com.android.settings",
                packageName = pkg,
                featuresForFlutter = listOf("settings_lockdown_trigger"),
                forceHome = true,
            )
            return
        }

        // Daily usage limit enforcement:
        // If user has ANY blocks enabled for this package and the daily limit is reached,
        // block the app until day rollover (midnight).
        if (hasRule && shouldApplyPackageUsageLimit(rules, pkg) && isUsageLimitReached(prefs, pkg)) {
            triggerLock(
                lockTarget = pkg,
                packageName = pkg,
                featuresForFlutter = listOf("usage_limit"),
                forceHome = false,
            )
            return
        }
        // Anti-uninstall: installer/Play Store use strict "uninstall our app" proximity (avoid WhatsApp/etc.).
        // Settings-like surfaces only when App Info shows uninstall/force-stop for NeuroLock.
        val needsAntiUninstallPin = shouldArmAntiUninstall &&
            AntiUninstallHeuristics.shouldArmAntiUninstallForSensitivePackage(this, event, pkg)

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
            // Do not return early while throttled: we still need downstream anti-uninstall
            // checks (e.g. package-installer surfaces) to run for repeated attempts.
        }

        // Note: legacy keyword-based detection (uninstall/force stop) is no longer needed,
        // because we now start lockdown as soon as Settings is on NOKKON's surface.

        // Do NOT allow the general "unlock window" to bypass uninstall protection.
        // (Delay unlock is for blocked content only, not for disabling/uninstalling NOKKON.)
        if (!hasRule && !needsAntiUninstallPin) return

        // Launcher long-press uninstall path (common on iQOO / Vivo):
        // Package installer surfaces can allow a very fast "OK" tap.
        // When uninstall UI is about NOKKON, instantly exit to HOME and show PIN.
        if (needsAntiUninstallPin && AntiUninstallHeuristics.isPackageInstallerSurface(pkg)) {
            triggerLock(
                lockTarget = packageName,
                packageName = pkg,
                featuresForFlutter = listOf("anti_uninstall_nokkon"),
                forceHome = true,
            )
            return
        }

        // After handling anti-uninstall, respect the unlock window for normal blocked features.
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
            forceHome = false,
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
        // Add "pending" time that hasn't been flushed yet.
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
            // Write under the day key of the previous package.
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
        if (last <= 0L) {
            lastUsageTickMs = now
            return
        }
        // Debounce writes; keep UX smooth (avoid constant pref commits).
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

        // Cover immediately to prevent interaction and minimize any UI flash.
        overlay.show()

        if (forceHome) {
            try {
                performGlobalAction(GLOBAL_ACTION_HOME)
            } catch (_: Throwable) {
            }
        }

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

        overlay.hideDelayed(if (forceHome) 1500 else 800)
    }

    private fun featureListForRules(rules: JSONObject, pkg: String): List<String> {
        val arr = rules.optJSONArray(pkg) ?: return emptyList()
        val out = ArrayList<String>()
        for (i in 0 until arr.length()) {
            val s = arr.optString(i, "")
            if (s.isBlank() || s == "__full__") continue
            // Release scope: only YouTube Shorts + Instagram Reels.
            if (pkg == FeatureBlockDetector.PKG_YOUTUBE && s == "shorts") out.add(s)
            if (pkg == FeatureBlockDetector.PKG_INSTAGRAM && s == "reels") out.add(s)
        }
        return out
    }

    private fun shouldBlockPackage(
        pkg: String,
        event: AccessibilityEvent,
        rules: JSONObject
    ): Boolean {
        val arr = rules.optJSONArray(pkg) ?: return false
        if (arr.length() == 0) return false

        val feats = mutableSetOf<String>()
        for (i in 0 until arr.length()) {
            feats.add(arr.optString(i, ""))
        }
        // Release scope: ignore legacy full-app and non-target packages/features.
        if (pkg == FeatureBlockDetector.PKG_YOUTUBE) {
            val shortsOnly = feats.intersect(setOf("shorts"))
            if (shortsOnly.isEmpty()) return false
            val ytShortsDetected = shouldBlockYouTubeShortsOnly(event)
            if (ytShortsDetected) {
                return shouldEnforceFeatureBlock(getSharedPreferences(prefsName, MODE_PRIVATE), pkg, "shorts")
            }
            return false
        }

        if (pkg == FeatureBlockDetector.PKG_INSTAGRAM) {
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
                val t = SystemClock.uptimeMillis()
                if (t - lastSocialProbeMs < 550) return false
                lastSocialProbeMs = t
            }
            if (!feats.contains("reels")) return false
            val reelsOnly = setOf("reels")
            if (FeatureBlockDetector.shouldBlockGenericSocial(this, event, reelsOnly, pkg)) {
                return shouldEnforceFeatureBlock(getSharedPreferences(prefsName, MODE_PRIVATE), pkg, "reels")
            }
            return false
        }

        return false
    }

    /**
     * Package-level usage limit should not force full-app lock when we're in
     * feature-only mode for Shorts/Reels.
     */
    private fun shouldApplyPackageUsageLimit(rules: JSONObject, pkg: String): Boolean {
        val arr = rules.optJSONArray(pkg) ?: return false
        if (arr.length() == 0) return false
        val feats = mutableSetOf<String>()
        for (i in 0 until arr.length()) {
            feats.add(arr.optString(i, ""))
        }
        // Release scope: package-level limits are disabled for feature-only mode.
        if (pkg == FeatureBlockDetector.PKG_YOUTUBE) {
            return feats.contains("__full__") || feats.contains("videos")
        }
        if (pkg == FeatureBlockDetector.PKG_INSTAGRAM) {
            return feats.contains("__full__") || feats.contains("stories") || feats.contains("messages")
        }
        return false
    }

    private fun hasSupportedReleaseRule(rules: JSONObject, pkg: String): Boolean {
        if (pkg != FeatureBlockDetector.PKG_YOUTUBE && pkg != FeatureBlockDetector.PKG_INSTAGRAM) {
            return false
        }
        val arr = rules.optJSONArray(pkg) ?: return false
        if (arr.length() == 0) return false
        for (i in 0 until arr.length()) {
            val f = arr.optString(i, "")
            if (pkg == FeatureBlockDetector.PKG_YOUTUBE && f == "shorts") return true
            if (pkg == FeatureBlockDetector.PKG_INSTAGRAM && f == "reels") return true
        }
        return false
    }

    /**
     * For timed feature blocks (YouTube Shorts / Instagram Reels):
     * - while user still has remaining allowance minutes, do not block
     * - once allowance is exhausted for today, enforce block.
     */
    private fun shouldEnforceFeatureBlock(
        prefs: android.content.SharedPreferences,
        pkg: String,
        feature: String,
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
        val spent = prefs.getLong(msKey, 0L)
        return spent >= (limitMin * 60_000L)
    }

    /** Shorts / full videos toggles map to separate UI probes — never block all of YouTube unless [__full__]. */
    private fun shouldBlockYouTube(
        event: AccessibilityEvent,
        feats: Set<String>
    ): Boolean {
        val wantShorts = feats.contains("shorts")
        val wantVideos = feats.contains("videos")

        val onlyShorts = wantShorts && !wantVideos
        if (onlyShorts) {
            return shouldBlockYouTubeShortsOnly(event)
        }

        if (!wantShorts && !wantVideos) return false

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            val t = SystemClock.uptimeMillis()
            if (t - lastYtShortsProbeMs < 700) return false
            lastYtShortsProbeMs = t
        }

        if (wantShorts && youtubeShortsSurfaceShouldBlock(event)) return true

        val root = rootInActiveWindow ?: return false
        try {
            if (wantVideos && youtubeStandardVideoShouldBlock(event, root)) return true
        } finally {
            root.recycle()
        }
        return false
    }

    private fun youtubeStandardVideoShouldBlock(
        event: AccessibilityEvent,
        root: AccessibilityNodeInfo,
    ): Boolean {
        // Avoid triggering on Shorts / vertical reel surfaces.
        val nav = readYouTubeBottomNavState(root)
        if (ReferenceBlockHeuristics.youtubeHasReelSurface(root) &&
            (nav.shortsSelected || !nav.homeSelected)
        ) {
            return false
        }
        if (findStrictShortsPlayer(root, 0)) return false

        val cls = event.className?.toString()?.lowercase() ?: ""
        // Common YouTube watch activities (varies by version).
        if (cls.contains("watch") && !cls.contains("shorts") && !cls.contains("reel")) {
            return true
        }
        // Conservative view-id scan for "player/watch" surfaces while excluding shorts/reel ids.
        return findYouTubeStandardPlayer(root, 0)
    }

    private fun findYouTubeStandardPlayer(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 42) return false
        try {
            val id = node.viewIdResourceName?.lowercase() ?: ""
            if (id.isNotBlank()) {
                if ((id.contains("player") || id.contains("watch")) &&
                    !id.contains("shorts") &&
                    !id.contains("reel") &&
                    !id.contains("shelf") &&
                    !id.contains("thumbnail") &&
                    !id.contains("chip") &&
                    !id.contains("tab")
                ) {
                    return true
                }
            }
        } catch (_: Exception) {
        }
        for (i in 0 until node.childCount) {
            val c = node.getChild(i) ?: continue
            if (findYouTubeStandardPlayer(c, depth + 1)) return true
        }
        return false
    }

    /**
     * "Shorts only" must not lock Home / Subscriptions / Watch — only the Shorts tab
     * or an embedded vertical Shorts / Reel player.
     */
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
            // Reference xblockit: reel_recycler — restrict on Home tab to avoid shelf false positives
            if (ReferenceBlockHeuristics.youtubeHasReelSurface(root) &&
                (nav.shortsSelected || !nav.homeSelected)
            ) {
                return true
            }
            val player = findStrictShortsPlayer(root, 0)
            if (player) return true
            if (nav.homeSelected && !nav.shortsSelected) return false
            if (nav.shortsSelected) return true
            return false
        } finally {
            root.recycle()
        }
    }

    private data class YtBottomNav(val homeSelected: Boolean, val shortsSelected: Boolean)

    private fun readYouTubeBottomNavState(root: AccessibilityNodeInfo?): YtBottomNav {
        if (root == null) return YtBottomNav(false, false)
        var home = false
        var shorts = false
        fun walk(n: AccessibilityNodeInfo?, depth: Int) {
            if (n == null || depth > 42) return
            try {
                if (n.isSelected) {
                    val cd = n.contentDescription?.toString()?.lowercase()?.trim() ?: ""
                    val tx = n.text?.toString()?.lowercase()?.trim() ?: ""
                    if (cd == "home" || tx == "home" || cd.contains("home") && cd.contains("tab")) {
                        home = true
                    }
                    if (cd == "shorts" || cd.startsWith("shorts,") || tx == "shorts" ||
                        (cd.contains("shorts") && !cd.contains("shortcut"))
                    ) {
                        shorts = true
                    }
                }
            } catch (_: Exception) {
            }
            for (i in 0 until n.childCount) {
                walk(n.getChild(i), depth + 1)
            }
        }
        walk(root, 0)
        return YtBottomNav(home, shorts)
    }

    /** Shorts rail or reel player — avoids matching Home shelves / random "shorts" text. */
    private fun youtubeShortsSurfaceShouldBlock(event: AccessibilityEvent): Boolean {
        val cls = event.className?.toString()?.lowercase() ?: ""
        if (cls.contains("reel") && (cls.contains("shorts") || cls.contains("watch"))) return true
        if (cls.contains("shorts") && cls.contains("activity")) return true
        val root = rootInActiveWindow ?: return false
        try {
            val nav = readYouTubeBottomNavState(root)
            if (ReferenceBlockHeuristics.youtubeHasReelSurface(root) &&
                (nav.shortsSelected || !nav.homeSelected)
            ) {
                return true
            }
            val player = findStrictShortsPlayer(root, 0)
            if (player) return true
            if (nav.homeSelected && !nav.shortsSelected) return false
            if (nav.shortsSelected) return true
            return false
        } finally {
            root.recycle()
        }
    }

    private fun findYouTubeFeedSurface(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 48) return false
        try {
            val id = node.viewIdResourceName?.lowercase() ?: ""
            if (id.contains("shorts") &&
                (id.contains("player") || id.contains("reel") || id.contains("watch"))
            ) {
                return false
            }
            if (id.contains("compact_video") || id.contains("video_with_context") ||
                id.contains("rich_item") || id.contains("watch_card") || id.contains("med_card")
            ) {
                return true
            }
            val cls = node.className?.toString()?.lowercase() ?: ""
            if (id.contains("browse") && cls.contains("fragment")) return true
            if (id.contains("tab_content") && !id.contains("shorts")) return true
        } catch (_: Exception) {
        }
        for (i in 0 until node.childCount) {
            val c = node.getChild(i) ?: continue
            if (findYouTubeFeedSurface(c, depth + 1)) return true
        }
        return false
    }

    private fun findYouTubeStoriesOrReelsSurface(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 48) return false
        try {
            val id = node.viewIdResourceName?.lowercase() ?: ""
            if (id.contains("story") && !id.contains("history") && depth >= 4) return true
        } catch (_: Exception) {
        }
        for (i in 0 until node.childCount) {
            val c = node.getChild(i) ?: continue
            if (findYouTubeStoriesOrReelsSurface(c, depth + 1)) return true
        }
        return false
    }

    /** Vertical Shorts / Reel watch surfaces only (not shelves, chips, or nav). */
    private fun findStrictShortsPlayer(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 42) return false
        try {
            val id = node.viewIdResourceName?.lowercase() ?: ""
            if (looksLikeShortsPlayerId(id)) return true
        } catch (_: Exception) {
        }
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
        ) {
            return false
        }
        return id.contains("player") || id.contains("watch") || id.contains("pager") ||
            id.contains("viewer") || id.contains("surface") || id.contains("watch_frame")
    }

    override fun onInterrupt() {}
}

/**
 * Minimal full-screen accessibility overlay used to prevent UI interaction and reduce
 * sensitive app flashes while the Flutter lock route is being brought to front.
 */
private class BlockingOverlay(private val service: AccessibilityService) {
    private val wm by lazy { service.getSystemService(Context.WINDOW_SERVICE) as WindowManager }
    private var view: View? = null
    private val handler by lazy { Handler(service.mainLooper) }

    fun show() {
        if (view != null) return
        val v = View(service).apply {
            // Fully opaque black "instant cover".
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
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }
        try {
            wm.addView(v, lp)
            view = v
        } catch (_: Throwable) {
            view = null
        }
    }

    fun hide() {
        val v = view ?: return
        view = null
        try {
            wm.removeView(v)
        } catch (_: Throwable) {
        }
    }

    fun hideDelayed(ms: Long) {
        handler.removeCallbacksAndMessages(null)
        handler.postDelayed({ hide() }, ms)
    }
}

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

class AppBlockerService : AccessibilityService() {

    companion object {
        private const val PREFS = "impulse_control"
        private const val KEY_RULES_JSON = "blocked_rules_json"
        private const val KEY_INVITE_ROTATION_PENDING = "invite_rotation_pending"
        private const val KEY_SETTINGS_LOCKDOWN_UNTIL_MS = "settings_lockdown_until_ms"
        private const val SETTINGS_LOCKDOWN_MS = 10 * 60 * 1000L
        @Volatile
        private var rulesJson: String = "{}"

        private var lastTriggered = ""
        private var lastTime = 0L
        private var lastYtShortsProbeMs = 0L
        private var lastSocialProbeMs = 0L

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

        val shouldArmAntiUninstall = pinSet || inviteRotationPending

        // Strict Settings lockdown: while active, Settings should never be visible.
        val settingsLockdownUntil = prefs.getLong(KEY_SETTINGS_LOCKDOWN_UNTIL_MS, 0L)
        val settingsLockdownActive = settingsLockdownUntil > System.currentTimeMillis()
        if (settingsLockdownActive && AntiUninstallHeuristics.isSettingsPackage(pkg)) {
            triggerLock(
                lockTarget = "com.android.settings",
                packageName = pkg,
                featuresForFlutter = listOf("settings_lockdown"),
                forceHome = true,
            )
            return
        }

        // Settings strict protection (AppLock style):
        // The moment we detect the user is on NOKKON's surface inside Settings,
        // we immediately kick them out and lock Settings for 10 minutes.
        //
        // This prevents the iterative bypass: close PIN -> tap one button -> close PIN -> tap again.
        val settingsMentionsSelf = shouldArmAntiUninstall &&
            !unlocked &&
            AntiUninstallHeuristics.isSettingsPackage(pkg) &&
            AntiUninstallHeuristics.shouldRequirePinThrottled(this, event)
        if (settingsMentionsSelf) {
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

        val rules = try {
            JSONObject(rulesJson)
        } catch (_: Exception) {
            JSONObject()
        }
        val hasRule = rules.has(pkg)
        // Anti-uninstall does not require block rules JSON to be non-empty (PIN alone is enough).
        val needsAntiUninstallPin = shouldArmAntiUninstall &&
            AntiUninstallHeuristics.isSensitiveUninstallSurface(pkg) &&
            AntiUninstallHeuristics.shouldRequirePinThrottled(this, event)

        // Note: legacy keyword-based detection (uninstall/force stop) is no longer needed,
        // because we now start lockdown as soon as Settings is on NOKKON's surface.

        if (unlocked) return
        if (!hasRule && !needsAntiUninstallPin) return

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
            if (s.isNotBlank() && s != "__full__") out.add(s)
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
        if (feats.contains("__full__")) return true

        if (pkg == FeatureBlockDetector.PKG_YOUTUBE) {
            return shouldBlockYouTube(event, feats)
        }
        if (pkg == FeatureBlockDetector.PKG_INSTAGRAM ||
            pkg == FeatureBlockDetector.PKG_SNAPCHAT
        ) {
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
                val t = SystemClock.uptimeMillis()
                if (t - lastSocialProbeMs < 550) return false
                lastSocialProbeMs = t
            }
            return FeatureBlockDetector.shouldBlockGenericSocial(this, event, feats, pkg)
        }

        return true
    }

    /** Shorts / feed / stories / reels toggles map to separate UI probes — never block all of YouTube unless [__full__]. */
    private fun shouldBlockYouTube(
        event: AccessibilityEvent,
        feats: Set<String>
    ): Boolean {
        val wantShorts = feats.contains("shorts")
        val wantFeed = feats.contains("feed")
        val wantStories = feats.contains("stories")
        val wantReels = feats.contains("reels")

        val onlyShorts = wantShorts && !wantFeed && !wantStories && !wantReels
        if (onlyShorts) {
            return shouldBlockYouTubeShortsOnly(event)
        }

        if (!wantShorts && !wantFeed && !wantStories && !wantReels) return false

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            val t = SystemClock.uptimeMillis()
            if (t - lastYtShortsProbeMs < 700) return false
            lastYtShortsProbeMs = t
        }

        var hitShorts = false
        if (wantShorts) {
            hitShorts = youtubeShortsSurfaceShouldBlock(event)
        }
        if (hitShorts) return true

        val root = rootInActiveWindow ?: return false
        try {
            val nav = readYouTubeBottomNavState(root)
            if ((wantShorts || wantReels) &&
                ReferenceBlockHeuristics.youtubeHasReelRecycler(root) &&
                (nav.shortsSelected || !nav.homeSelected)
            ) {
                return true
            }
            if (wantFeed && findYouTubeFeedSurface(root, 0)) return true
            if ((wantStories || wantReels) && findYouTubeStoriesOrReelsSurface(root, 0)) {
                return true
            }
            if (wantReels && findStrictShortsPlayer(root, 0)) return true
            if (wantStories && FeatureBlockDetector.containsAnyKeyword(
                    root,
                    FeatureBlockDetector.keywordsForFeature("stories"),
                )
            ) {
                return true
            }
        } finally {
            root.recycle()
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
            if (ReferenceBlockHeuristics.youtubeHasReelRecycler(root) &&
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
            if (ReferenceBlockHeuristics.youtubeHasReelRecycler(root) &&
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

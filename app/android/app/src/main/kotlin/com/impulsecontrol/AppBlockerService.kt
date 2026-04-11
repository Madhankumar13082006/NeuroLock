package com.impulsecontrol

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.embedding.android.FlutterActivity
import org.json.JSONArray
import org.json.JSONObject

class AppBlockerService : AccessibilityService() {

    companion object {
        private const val PREFS = "impulse_control"
        private const val KEY_RULES_JSON = "blocked_rules_json"
        private const val KEY_INVITE_ROTATION_PENDING = "invite_rotation_pending"
        private const val YOUTUBE = "com.google.android.youtube"

        @Volatile
        private var rulesJson: String = "{}"

        private var lastTriggered = ""
        private var lastTime = 0L
        private var lastYtShortsProbeMs = 0L

        private val restrictedPackages = setOf(
            "com.google.android.packageinstaller",
            "com.android.packageinstaller",
            "com.miui.packageinstaller",
            "com.samsung.android.packageinstaller",
            "com.android.settings"
        )

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

    override fun onServiceConnected() {
        loadRulesFromPrefs(this)
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes =
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 100
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val pkg = event.packageName?.toString() ?: return

        val prefs = getSharedPreferences(prefsName, MODE_PRIVATE)
        val unlockUntil = prefs.getLong(keyUnlockUntil, 0L)
        val pinSet = prefs.getBoolean(keyPinSet, false)
        val inviteRotationPending = prefs.getBoolean(KEY_INVITE_ROTATION_PENDING, false)
        val unlocked = unlockUntil > System.currentTimeMillis()

        val protectEnabled =
            (pinSet || inviteRotationPending) && rulesJson != "{}" && rulesJson.isNotBlank()
        val rules = try {
            JSONObject(rulesJson)
        } catch (_: Exception) {
            JSONObject()
        }
        val hasRule = rules.has(pkg)
        val isRestrictedAction = protectEnabled && pkg in restrictedPackages

        if (unlocked) return
        if (!hasRule && !isRestrictedAction) return

        if (hasRule && !shouldBlockPackage(pkg, event, rules)) return

        val now = System.currentTimeMillis()
        if (pkg == lastTriggered && now - lastTime < 3000) return
        lastTriggered = pkg
        lastTime = now

        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra("route", "/lock/$pkg")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        startActivity(intent)
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

        if (pkg == YOUTUBE) {
            return shouldBlockYouTube(event, feats)
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
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
                val t = SystemClock.uptimeMillis()
                if (t - lastYtShortsProbeMs < 700) return false
                lastYtShortsProbeMs = t
            }
            val clsOnly = event.className?.toString()?.lowercase() ?: ""
            if (clsOnly.contains("shorts") &&
                (clsOnly.contains("activity") || clsOnly.contains("fragment") || clsOnly.contains("watch"))
            ) {
                return true
            }
            val rootOnly = rootInActiveWindow ?: return false
            val hitOnly = findShortsUi(rootOnly, 0)
            rootOnly.recycle()
            return hitOnly
        }

        if (!wantShorts && !wantFeed && !wantStories && !wantReels) return false

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            val t = SystemClock.uptimeMillis()
            if (t - lastYtShortsProbeMs < 700) return false
            lastYtShortsProbeMs = t
        }

        var hitShorts = false
        if (wantShorts) {
            val cls = event.className?.toString()?.lowercase() ?: ""
            if (cls.contains("shorts") &&
                (cls.contains("activity") || cls.contains("fragment") || cls.contains("watch"))
            ) {
                hitShorts = true
            }
            if (!hitShorts) {
                val rootS = rootInActiveWindow
                if (rootS != null) {
                    try {
                        hitShorts = findShortsUi(rootS, 0)
                    } finally {
                        rootS.recycle()
                    }
                }
            }
        }
        if (hitShorts) return true

        val root = rootInActiveWindow ?: return false
        try {
            if (wantFeed && findYouTubeFeedSurface(root, 0)) return true
            if ((wantStories || wantReels) && findYouTubeStoriesOrReelsSurface(root, 0)) {
                return true
            }
            // YouTube "Reels" toggle maps to the Shorts-style vertical feed.
            if (wantReels && findShortsUi(root, 0)) return true
        } finally {
            root.recycle()
        }
        return false
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

    private fun findShortsUi(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 40) return false
        try {
            val id = node.viewIdResourceName?.lowercase() ?: ""
            // Avoid bottom-nav / home shelf false positives (still in main YouTube).
            if (id.contains("thumbnail") || id.contains("avatar") || id.contains("shelf") ||
                id.contains("chip") || id.contains("tab") || id.contains("navigation")
            ) {
                // Still recurse; do not match on this node alone.
            } else if (looksLikeShortsSurface(id)) {
                return true
            }
            val cd = node.contentDescription?.toString()?.lowercase()?.trim() ?: ""
            if ((cd == "shorts" || cd.startsWith("shorts,")) && depth >= 6) return true
            val tx = node.text?.toString()?.lowercase()?.trim() ?: ""
            if (tx == "shorts" && depth >= 6) return true
        } catch (_: Exception) {
        }
        for (i in 0 until node.childCount) {
            val c = node.getChild(i) ?: continue
            if (findShortsUi(c, depth + 1)) return true
        }
        return false
    }

    /** True for player / watch surfaces, not home tabs or shelves. */
    private fun looksLikeShortsSurface(id: String): Boolean {
        if (!id.contains("shorts")) return false
        return id.contains("player") || id.contains("watch") || id.contains("reel") ||
            id.contains("pager") || id.contains("viewer") || id.contains("surface")
    }

    override fun onInterrupt() {}
}

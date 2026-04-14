package com.impulsecontrol

import android.accessibilityservice.AccessibilityService
import android.os.Build
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Targeted anti-uninstall (reference: `reffer for AI/services/AppBlockerService.kt` —
 * "SMART SETTINGS PROTECTION" / page-aware checks instead of locking all of Settings).
 *
 * Only requests a PIN when the foreground UI clearly concerns **this** app
 * (app info, uninstall, open-by-default, storage for NOKKON, etc.).
 */
object AntiUninstallHeuristics {

    /** Must match [android.defaultConfig.applicationId] in build.gradle.kts */
    private const val SELF_PACKAGE = "com.impulsecontrol"

    private val SELF_LABEL_MARKERS = listOf(
        "nokkon",
        "impulsecontrol",
    )

    /**
     * Surfaces that can remove the app or strip accessibility; each is gated by
     * [shouldRequirePinForCurrentWindow], not blocked wholesale.
     */
    val UNINSTALL_SENSITIVE_PACKAGES: Set<String> = setOf(
        "com.google.android.packageinstaller",
        "com.android.packageinstaller",
        "com.miui.packageinstaller",
        "com.samsung.android.packageinstaller",
        "com.android.settings",
        "com.google.android.settings",
        "com.samsung.android.settings",
        "com.android.vending",
        "com.google.android.permissioncontroller",
        "com.miui.securitycenter",
        "com.huawei.systemmanager",
    )

    fun isSensitiveUninstallSurface(packageName: String): Boolean =
        packageName in UNINSTALL_SENSITIVE_PACKAGES

    fun isSettingsPackage(packageName: String): Boolean =
        packageName == "com.android.settings" ||
            packageName == "com.google.android.settings" ||
            packageName == "com.samsung.android.settings"

    fun isPackageInstallerSurface(packageName: String): Boolean =
        packageName == "com.google.android.packageinstaller" ||
            packageName == "com.android.packageinstaller" ||
            packageName == "com.miui.packageinstaller" ||
            packageName == "com.samsung.android.packageinstaller" ||
            packageName == "com.google.android.permissioncontroller" ||
            packageName == "com.android.permissioncontroller"

    /**
     * True if the event or active window tree references NOKKON / this package.
     */
    fun shouldRequirePinForCurrentWindow(
        service: AccessibilityService,
        event: AccessibilityEvent,
    ): Boolean {
        if (quickEventFieldsMatch(event)) return true
        val root = service.rootInActiveWindow ?: return false
        return try {
            treeMentionsSelf(root, 0)
        } finally {
            root.recycle()
        }
    }

    private fun quickEventFieldsMatch(event: AccessibilityEvent): Boolean {
        try {
            val list = event.text
            if (list != null) {
                for (i in 0 until list.size) {
                    val cs = list[i] ?: continue
                    if (blobMentionsSelf(cs.toString())) return true
                }
            }
            event.contentDescription?.let {
                if (blobMentionsSelf(it.toString())) return true
            }
        } catch (_: Exception) {
        }
        return false
    }

    private fun blobMentionsSelf(s: String): Boolean {
        val b = s.lowercase()
        if (b.contains(SELF_PACKAGE.lowercase())) return true
        for (m in SELF_LABEL_MARKERS) {
            if (m.length >= 4 && b.contains(m.lowercase())) return true
        }
        return false
    }

    private fun treeMentionsSelf(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 56) return false
        try {
            val id = node.viewIdResourceName?.lowercase() ?: ""
            if (id.contains("impulsecontrol") || id.contains("nokkon")) return true
            node.text?.toString()?.let { if (blobMentionsSelf(it)) return true }
            node.contentDescription?.toString()?.let { if (blobMentionsSelf(it)) return true }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                node.hintText?.toString()?.let { if (blobMentionsSelf(it)) return true }
            }
        } catch (_: Exception) {
        }
        val n = node.childCount
        for (i in 0 until n) {
            val c = node.getChild(i) ?: continue
            if (treeMentionsSelf(c, depth + 1)) return true
        }
        return false
    }

    /** Throttle expensive tree walks on noisy content-changed (reference debounce ~500ms). */
    @Volatile
    private var lastContentTreeMs = 0L

    @Volatile
    private var lastContentTreeResult = false

    fun shouldRequirePinThrottled(
        service: AccessibilityService,
        event: AccessibilityEvent,
    ): Boolean {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            lastContentTreeMs = 0L
            lastContentTreeResult = false
        }
        if (quickEventFieldsMatch(event)) return true
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            return shouldRequirePinForCurrentWindow(service, event)
        }
        val now = SystemClock.uptimeMillis()
        if (lastContentTreeMs > 0L && now - lastContentTreeMs < 480) {
            return lastContentTreeResult
        }
        lastContentTreeMs = now
        val r = shouldRequirePinForCurrentWindow(service, event)
        lastContentTreeResult = r
        return r
    }

    private val SETTINGS_DANGER_KEYWORDS = listOf(
        "uninstall",
        "force stop",
        "force-stop",
    )

    /**
     * True when the current Settings UI appears to be the NOKKON App Info surface
     * where "Uninstall" / "Force stop" actions are available.
     */
    fun shouldStartSettingsLockdown(
        service: AccessibilityService,
        event: AccessibilityEvent,
    ): Boolean {
        val pkg = event.packageName?.toString() ?: return false
        if (!isSettingsPackage(pkg)) return false

        // Must be about NOKKON specifically; avoid blocking Settings for other apps.
        val mentionsSelf = shouldRequirePinThrottled(service, event)
        if (!mentionsSelf) return false

        val root = service.rootInActiveWindow ?: return false
        return try {
            containsAnyText(root, SETTINGS_DANGER_KEYWORDS, 0)
        } finally {
            root.recycle()
        }
    }

    private fun containsAnyText(
        node: AccessibilityNodeInfo?,
        needles: List<String>,
        depth: Int,
    ): Boolean {
        if (node == null || depth > 56) return false
        try {
            val t = node.text?.toString()?.lowercase() ?: ""
            val cd = node.contentDescription?.toString()?.lowercase() ?: ""
            val id = node.viewIdResourceName?.toString()?.lowercase() ?: ""
            for (n in needles) {
                val k = n.lowercase()
                val idNeedle = k.replace(" ", "_")
                if (t.contains(k) || cd.contains(k) || (idNeedle.isNotBlank() && id.contains(idNeedle))) {
                    return true
                }
            }
        } catch (_: Exception) {
        }
        val c = node.childCount
        for (i in 0 until c) {
            if (containsAnyText(node.getChild(i), needles, depth + 1)) return true
        }
        return false
    }
}

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
 * (app info, uninstall, open-by-default, storage for neurolock , etc.).
 */
object AntiUninstallHeuristics {

    /** Must match [android.defaultConfig.applicationId] in build.gradle.kts */
    private const val SELF_PACKAGE = "com.impulsecontrol"

    private val SELF_LABEL_MARKERS = listOf(
        "neurolock",
        "neuro lock",
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

    /**
     * OEMs often split App Info / Force Stop / Uninstall UI across security or
     * permission apps instead of plain Settings. Treat these as Settings-like
     * for strict lockdown once NOKKON's management surface is detected.
     */
    fun isSettingsLikeSurface(packageName: String): Boolean =
        isSettingsPackage(packageName) ||
            packageName == "com.google.android.permissioncontroller" ||
            packageName == "com.android.permissioncontroller" ||
            packageName == "com.vivo.permissionmanager" ||
            packageName == "com.iqoo.secure" ||
            packageName == "com.miui.securitycenter" ||
            packageName == "com.huawei.systemmanager" ||
            packageName.contains("settings") ||
            packageName.contains("securitycenter") ||
            packageName.contains("permissioncontroller") ||
            packageName.contains("permissionmanager") ||
            packageName.contains("systemmanager")

    fun isPackageInstallerSurface(packageName: String): Boolean =
        packageName == "com.google.android.packageinstaller" ||
            packageName == "com.android.packageinstaller" ||
            packageName == "com.miui.packageinstaller" ||
            packageName == "com.samsung.android.packageinstaller" ||
            packageName == "com.google.android.permissioncontroller" ||
            packageName == "com.android.permissioncontroller"

    /** Hints that the UI is an uninstall/remove-app flow (avoid bare "delete"). */
    private val UNINSTALL_DIALOG_HINTS = listOf(
        "uninstall",
        "remove app",
        "remove this app",
        "delete this app",
        "app will be deleted",
        "desinstalar",
        "supprimer",
        "deinstallieren",
        "eliminar",
    )

    private val SETTINGS_MANAGEMENT_DANGER = listOf(
        "uninstall",
        "force stop",
        "force-stop",
        "clear data",
        "clear storage",
        "disable",
    )

    /** NeuroLock accessibility service detail screen (Use NeuroLock toggle). */
    private val ACCESSIBILITY_SELF_MARKERS = listOf(
        "use neurolock",
        "neurolock shortcut",
        "app blocker for impulse",
        "blocks access to addictive",
        "accessibility service",
        "installed services",
    )

    private fun windowAround(s: String, centerIdx: Int, radius: Int): String {
        val start = (centerIdx - radius).coerceAtLeast(0)
        val end = (centerIdx + radius).coerceAtMost(s.length)
        return if (start >= end) "" else s.substring(start, end)
    }

    private fun appendNodeTextTo(node: AccessibilityNodeInfo?, depth: Int, out: StringBuilder) {
        if (node == null || depth > 56) return
        try {
            node.text?.toString()?.let { if (it.isNotBlank()) out.append(' ').append(it) }
            node.contentDescription?.toString()?.let { if (it.isNotBlank()) out.append(' ').append(it) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                node.hintText?.toString()?.let { if (it.isNotBlank()) out.append(' ').append(it) }
            }
        } catch (_: Exception) {
        }
        val n = node.childCount
        for (i in 0 until n) {
            appendNodeTextTo(node.getChild(i), depth + 1, out)
        }
    }

    private fun flatHasSelfNearKeywords(flat: String, keywords: List<String>): Boolean {
        val l = flat.lowercase()
        val kl = keywords.map { it.lowercase() }
        if (!kl.any { it.isNotBlank() && l.contains(it) }) return false
        return selfMarkerNearDangerFlat(l, kl)
    }

    private fun selfMarkerNearDangerFlat(l: String, dangerNeedles: List<String>): Boolean {
        val selfNeedles = listOf(
            SELF_PACKAGE.lowercase(),
            "neurolock",
            "neuro lock",
            "nokkon",
            "impulsecontrol",
        )
        for (d in dangerNeedles) {
            if (d.isBlank()) continue
            var start = 0
            while (start < l.length) {
                val i = l.indexOf(d, start)
                if (i < 0) break
                val center = i + d.length / 2
                val w = windowAround(l, center, 90)
                if (blobMentionsSelf(w)) return true
                start = i + d.length
            }
        }
        for (needle in selfNeedles) {
            if (needle.length < 4) continue
            var start = 0
            while (start < l.length) {
                val i = l.indexOf(needle, start)
                if (i < 0) break
                val center = i + needle.length / 2
                val w = windowAround(l, center, 90)
                if (dangerNeedles.any { d -> d.isNotBlank() && w.contains(d) }) return true
                start = i + needle.length
            }
        }
        return false
    }

    private fun combinedUninstallTextTargetsSelf(blob: String): Boolean =
        flatHasSelfNearKeywords(blob, UNINSTALL_DIALOG_HINTS)

    private fun settingsFlatIndicatesSelfManagementDanger(blob: String): Boolean =
        flatHasSelfNearKeywords(blob, SETTINGS_MANAGEMENT_DANGER)

    fun uninstallDialogTargetsSelfFromRoot(root: AccessibilityNodeInfo): Boolean {
        val sb = StringBuilder()
        appendNodeTextTo(root, 0, sb)
        return combinedUninstallTextTargetsSelf(sb.toString())
    }

    fun uninstallDialogTargetsSelf(service: AccessibilityService): Boolean {
        val root = service.rootInActiveWindow ?: return false
        return try {
            uninstallDialogTargetsSelfFromRoot(root)
        } finally {
            root.recycle()
        }
    }

    fun eventLooksLikeUninstallOfSelf(event: AccessibilityEvent): Boolean {
        val sb = StringBuilder()
        try {
            val list = event.text
            if (list != null) {
                for (i in 0 until list.size) {
                    val cs = list[i] ?: continue
                    if (cs.isNotBlank()) sb.append(' ').append(cs)
                }
            }
            event.contentDescription?.let { if (it.isNotBlank()) sb.append(' ').append(it) }
        } catch (_: Exception) {
        }
        val s = sb.toString()
        if (s.isBlank()) return false
        return combinedUninstallTextTargetsSelf(s)
    }

    @Volatile
    private var uninstallThrottleMs = 0L

    @Volatile
    private var uninstallThrottleResult = false

    @Volatile
    private var uninstallThrottlePkg: String? = null

    fun uninstallDialogTargetsSelfThrottled(
        service: AccessibilityService,
        event: AccessibilityEvent,
    ): Boolean {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            uninstallThrottleMs = 0L
            uninstallThrottleResult = false
            uninstallThrottlePkg = null
        }
        if (eventLooksLikeUninstallOfSelf(event)) return true
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            return uninstallDialogTargetsSelf(service)
        }
        val p = event.packageName?.toString() ?: ""
        if (p != uninstallThrottlePkg) {
            uninstallThrottlePkg = p
            uninstallThrottleMs = 0L
            uninstallThrottleResult = false
        }
        val now = SystemClock.uptimeMillis()
        if (uninstallThrottleMs > 0L && now - uninstallThrottleMs < 480) {
            return uninstallThrottleResult
        }
        uninstallThrottleMs = now
        val r = uninstallDialogTargetsSelf(service)
        uninstallThrottleResult = r
        return r
    }

    /**
     * Gate anti-uninstall: Play Store / installers need uninstall+NeuroLock proximity;
     * Settings-like surfaces need management actions (uninstall, force stop, …) near NeuroLock.
     */
    fun shouldArmAntiUninstallForSensitivePackage(
        service: AccessibilityService,
        event: AccessibilityEvent,
        packageName: String,
    ): Boolean {
        if (!isSensitiveUninstallSurface(packageName)) return false
        if (isPackageInstallerSurface(packageName) || packageName == "com.android.vending") {
            return uninstallDialogTargetsSelfThrottled(service, event)
        }
        if (isSettingsLikeSurface(packageName)) {
            return shouldStartSettingsLockdown(service, event)
        }
        return false
    }

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
            if (id.contains("impulsecontrol") || id.contains("nokkon") || id.contains("neurolock")) {
                return true
            }
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

    /** Package name for the last throttled CONTENT_CHANGED sample (null after WINDOW_STATE_CHANGED). */
    @Volatile
    private var lastContentThrottlePkg: String? = null

    fun shouldRequirePinThrottled(
        service: AccessibilityService,
        event: AccessibilityEvent,
    ): Boolean {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            lastContentTreeMs = 0L
            lastContentTreeResult = false
            lastContentThrottlePkg = null
        }
        if (quickEventFieldsMatch(event)) return true
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            return shouldRequirePinForCurrentWindow(service, event)
        }
        val pkg = event.packageName?.toString() ?: ""
        // Invalidate throttle when foreground package changes. Otherwise launcher noise can
        // cache "false" and the next package-installer CONTENT_CHANGED within ~480ms reuses it,
        // skipping a fresh tree walk — repeat uninstall attempts then slip through.
        if (pkg != lastContentThrottlePkg) {
            lastContentThrottlePkg = pkg
            lastContentTreeMs = 0L
            lastContentTreeResult = false
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

    /**
     * True when the current Settings UI shows destructive/management actions for NeuroLock
     * (uninstall, force stop, clear data, …) — uses proximity so other apps' App Info pages
     * that merely mention NeuroLock in a list do not trigger.
     */
    /**
     * Blocks the system screen where the user can turn off "Use NeuroLock"
     * (Accessibility → NeuroLock → toggle), same protection tier as uninstall.
     */
    fun shouldBlockNeuroLockAccessibilityDetail(
        service: AccessibilityService,
        event: AccessibilityEvent,
    ): Boolean {
        val pkg = event.packageName?.toString() ?: return false
        if (!isSettingsLikeSurface(pkg)) return false
        if (quickEventFieldsMatch(event) && eventTextLooksLikeAccessibilityDetail(event)) {
            return true
        }
        val root = service.rootInActiveWindow ?: return false
        return try {
            val sb = StringBuilder()
            appendNodeTextTo(root, 0, sb)
            flatIndicatesNeuroLockAccessibilityDetail(sb.toString())
        } finally {
            root.recycle()
        }
    }

    private fun eventTextLooksLikeAccessibilityDetail(event: AccessibilityEvent): Boolean {
        val sb = StringBuilder()
        try {
            val list = event.text
            if (list != null) {
                for (i in 0 until list.size) {
                    val cs = list[i] ?: continue
                    if (cs.isNotBlank()) sb.append(' ').append(cs)
                }
            }
            event.contentDescription?.let { if (it.isNotBlank()) sb.append(' ').append(it) }
        } catch (_: Exception) {
        }
        return flatIndicatesNeuroLockAccessibilityDetail(sb.toString())
    }

    private fun flatIndicatesNeuroLockAccessibilityDetail(flat: String): Boolean {
        val l = flat.lowercase()
        if (!blobMentionsSelf(l)) return false
        return ACCESSIBILITY_SELF_MARKERS.any { marker ->
            marker.isNotBlank() && l.contains(marker)
        }
    }

    fun shouldStartSettingsLockdown(
        service: AccessibilityService,
        event: AccessibilityEvent,
    ): Boolean {
        val pkg = event.packageName?.toString() ?: return false
        if (!isSettingsLikeSurface(pkg)) return false
        val root = service.rootInActiveWindow ?: return false
        return try {
            val sb = StringBuilder()
            appendNodeTextTo(root, 0, sb)
            val flat = sb.toString()
            settingsFlatIndicatesSelfManagementDanger(flat) ||
                combinedUninstallTextTargetsSelf(flat)
        } finally {
            root.recycle()
        }
    }
}

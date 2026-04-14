package com.impulsecontrol

import android.accessibilityservice.AccessibilityService
import android.os.Build
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Extra guard for OEM launcher long-press uninstall flows (seen on some
 * IQOO/Vivo/launcher variants) where uninstall can be initiated before the
 * regular Settings-based heuristics react.
 */
object LauncherUninstallBypassShield {
    private const val SELF_PACKAGE = "com.impulsecontrol"
    private const val SELF_LABEL = "nokkon"
    private const val RECENT_SELF_WINDOW_MS = 12_000L

    private val OEM_MANUFACTURERS = setOf(
        "vivo",
        "iqoo",
        "oppo",
        "realme",
        "oneplus",
        "xiaomi",
        "redmi",
        "poco",
    )

    private val LAUNCHER_PACKAGES = setOf(
        "com.bbk.launcher2", // Vivo / iQOO
        "com.vivo.launcher",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.miui.home",
        "com.oppo.launcher",
        "com.coloros.launcher",
        "com.transsion.itel.launcher",
        "com.transsion.infinix.launcher",
    )

    private val UNINSTALL_KEYWORDS = listOf(
        "uninstall", "delete", "remove app", "app info", "ok", "remove",
        "desinstalar", "supprimer", "deinstallieren", "eliminar",
    )
    private val CONFIRMATION_KEYWORDS = listOf(
        "cancel", "close", "abort", "dismiss",
        "annuler", "abbrechen", "cancelar",
    )

    /**
     * Returns true when current launcher/installer screen likely belongs to
     * "long-press app icon -> uninstall" path for this app.
     */
    fun shouldForceLock(
        service: AccessibilityService,
        event: AccessibilityEvent,
        foregroundPackage: String,
        lastSelfSeenElapsedMs: Long,
    ): Boolean {
        val now = SystemClock.elapsedRealtime()
        if (lastSelfSeenElapsedMs <= 0L || now - lastSelfSeenElapsedMs > RECENT_SELF_WINDOW_MS) {
            return false
        }

        val maker = Build.MANUFACTURER.lowercase()
        val isOem = OEM_MANUFACTURERS.any { maker.contains(it) }
        val onLauncher = LAUNCHER_PACKAGES.contains(foregroundPackage)
        val onInstaller = AntiUninstallHeuristics.isPackageInstallerSurface(foregroundPackage)
        if (!onInstaller && !(isOem && onLauncher)) return false

        // Launcher content events are noisy on some OEM skins (IQOO/Vivo).
        // Restrict launcher detection to window-state changes to avoid blink loops.
        if (onLauncher && event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            return false
        }

        if (quickTextMentionsUninstall(event) &&
            quickTextMentionsSelf(event) &&
            (onInstaller || quickTextMentionsConfirmation(event))
        ) {
            return true
        }

        val root = service.rootInActiveWindow ?: return false
        return try {
            treeContainsAny(root, UNINSTALL_KEYWORDS, 0) &&
                (treeContainsText(root, SELF_LABEL, 0) || treeContainsText(root, SELF_PACKAGE, 0)) &&
                (onInstaller || treeContainsAny(root, CONFIRMATION_KEYWORDS, 0))
        } finally {
            root.recycle()
        }
    }

    private fun quickTextMentionsUninstall(event: AccessibilityEvent): Boolean {
        try {
            val texts = event.text
            if (texts != null) {
                for (i in 0 until texts.size) {
                    val s = texts[i]?.toString()?.lowercase() ?: continue
                    if (UNINSTALL_KEYWORDS.any { s.contains(it) }) return true
                }
            }
            val cd = event.contentDescription?.toString()?.lowercase() ?: ""
            if (UNINSTALL_KEYWORDS.any { cd.contains(it) }) return true
        } catch (_: Exception) {
        }
        return false
    }

    private fun quickTextMentionsSelf(event: AccessibilityEvent): Boolean {
        try {
            val texts = event.text
            if (texts != null) {
                for (i in 0 until texts.size) {
                    val s = texts[i]?.toString()?.lowercase() ?: continue
                    if (s.contains(SELF_LABEL) || s.contains(SELF_PACKAGE)) return true
                }
            }
            val cd = event.contentDescription?.toString()?.lowercase() ?: ""
            if (cd.contains(SELF_LABEL) || cd.contains(SELF_PACKAGE)) return true
        } catch (_: Exception) {
        }
        return false
    }

    private fun quickTextMentionsConfirmation(event: AccessibilityEvent): Boolean {
        try {
            val texts = event.text
            if (texts != null) {
                for (i in 0 until texts.size) {
                    val s = texts[i]?.toString()?.lowercase() ?: continue
                    if (CONFIRMATION_KEYWORDS.any { s.contains(it) }) return true
                }
            }
            val cd = event.contentDescription?.toString()?.lowercase() ?: ""
            if (CONFIRMATION_KEYWORDS.any { cd.contains(it) }) return true
        } catch (_: Exception) {
        }
        return false
    }

    private fun treeContainsAny(node: AccessibilityNodeInfo?, needles: List<String>, depth: Int): Boolean {
        if (node == null || depth > 56) return false
        try {
            val id = node.viewIdResourceName?.lowercase() ?: ""
            val tx = node.text?.toString()?.lowercase() ?: ""
            val cd = node.contentDescription?.toString()?.lowercase() ?: ""
            for (n in needles) {
                val idNeedle = n.replace(" ", "_")
                if (tx.contains(n) || cd.contains(n) || (idNeedle.isNotBlank() && id.contains(idNeedle))) {
                    return true
                }
            }
        } catch (_: Exception) {
        }
        for (i in 0 until node.childCount) {
            if (treeContainsAny(node.getChild(i), needles, depth + 1)) return true
        }
        return false
    }

    private fun treeContainsText(node: AccessibilityNodeInfo?, needle: String, depth: Int): Boolean {
        if (node == null || depth > 56) return false
        val n = needle.lowercase()
        try {
            if ((node.text?.toString()?.lowercase() ?: "").contains(n)) return true
            if ((node.contentDescription?.toString()?.lowercase() ?: "").contains(n)) return true
            if ((node.viewIdResourceName?.lowercase() ?: "").contains(n)) return true
        } catch (_: Exception) {
        }
        for (i in 0 until node.childCount) {
            if (treeContainsText(node.getChild(i), needle, depth + 1)) return true
        }
        return false
    }
}

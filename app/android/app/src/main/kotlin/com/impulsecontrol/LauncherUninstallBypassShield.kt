package com.impulsecontrol

import android.accessibilityservice.AccessibilityService
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Extra guard for OEM launcher long-press uninstall flows (seen on some
 * IQOO/Vivo/launcher variants) where uninstall can be initiated before the
 * regular Settings-based heuristics react.
 */
object LauncherUninstallBypassShield {
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
    ): Boolean {
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

        if ((onInstaller || quickTextMentionsConfirmation(event)) &&
            AntiUninstallHeuristics.eventLooksLikeUninstallOfSelf(event)
        ) {
            return true
        }

        val root = service.rootInActiveWindow ?: return false
        return try {
            (onInstaller || treeContainsAny(root, CONFIRMATION_KEYWORDS, 0)) &&
                AntiUninstallHeuristics.uninstallDialogTargetsSelfFromRoot(root)
        } finally {
            root.recycle()
        }
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
}

package com.impulsecontrol

import android.accessibilityservice.AccessibilityService
import android.os.Build
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Guards "long-press app icon → uninstall" and "drag-to-uninstall dropzone"
 * flows that some OEM launchers (Vivo/iQOO, MIUI, OneUI, ColorOS) handle
 * themselves before the system package installer opens.
 */
object LauncherUninstallBypassShield {

    private val OEM_MANUFACTURERS = setOf(
        "vivo", "iqoo", "oppo", "realme", "oneplus", "oplus",
        "xiaomi", "redmi", "poco", "samsung", "huawei", "honor",
        "motorola", "nothing", "tecno", "infinix", "itel",
        "asus", "lenovo", "sony", "nokia",
    )

    private val LAUNCHER_PACKAGES = setOf(
        // AOSP / Google
        "com.android.launcher", "com.android.launcher2", "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        // Samsung
        "com.sec.android.app.launcher",
        // Xiaomi / POCO
        "com.miui.home", "com.mi.android.globallauncher",
        // Oppo / Realme / OnePlus / OPlus
        "com.oppo.launcher", "com.coloros.launcher", "com.heytap.pictorial",
        "net.oneplus.launcher", "com.oneplus.launcher",
        // Vivo / iQOO
        "com.bbk.launcher2", "com.vivo.launcher",
        // Honor / Huawei
        "com.huawei.android.launcher", "com.hihonor.android.launcher",
        // Motorola / Lenovo
        "com.motorola.launcher3",
        // Nothing
        "com.nothing.launcher",
        // Transsion
        "com.transsion.itel.launcher", "com.transsion.infinix.launcher",
        "com.transsion.hilauncher",
        // Third-party
        "com.microsoft.launcher", "com.teslacoilsw.launcher",
        "ginlemon.flowerfree", "ginlemon.flowerpro",
        "com.actionlauncher.playstore", "com.anddoes.launcher",
        "bitpit.launcher",
    )

    // "Dropzone" / confirmation labels shown while dragging an icon to uninstall,
    // or on the quick long-press menu that offers uninstall.
    private val CONFIRMATION_KEYWORDS = listOf(
        // English
        "uninstall", "remove app", "app info", "cancel", "close",
        "abort", "dismiss", "confirm",
        // Hindi
        "अनइंस्टॉल",
        // Spanish / Portuguese
        "desinstalar", "cancelar",
        // French
        "désinstaller", "annuler",
        // German
        "deinstallieren", "abbrechen",
        // Chinese
        "卸载", "取消",
        // Japanese
        "アンインストール",
        // Korean
        "제거",
        // Russian
        "удалить",
    )

    // Throttle for launcher CONTENT_CHANGED — noisy but we need it (drag events)
    @Volatile private var lastLauncherContentMs = 0L
    @Volatile private var lastLauncherContentPkg: String? = null
    private const val LAUNCHER_THROTTLE_MS = 200L

    fun shouldForceLock(
        service: AccessibilityService,
        event: AccessibilityEvent,
        foregroundPackage: String,
    ): Boolean {
        val maker = try { Build.MANUFACTURER.lowercase() } catch (_: Exception) { "" }
        val isOem = OEM_MANUFACTURERS.any { maker.contains(it) }
        val onLauncher = LAUNCHER_PACKAGES.contains(foregroundPackage) ||
            AntiUninstallHeuristics.isLauncherSurface(foregroundPackage)
        val onInstaller = AntiUninstallHeuristics.isPackageInstallerSurface(foregroundPackage)
        if (!onInstaller && !(isOem && onLauncher) && !onLauncher) return false

        // Fast: event-text fields alone reveal the self-uninstall target
        if (AntiUninstallHeuristics.eventLooksLikeUninstallOfSelf(event)) return true

        // Handle content-changed on launcher with a throttle (drag-to-uninstall
        // fires a LOT of CONTENT_CHANGED as the icon moves toward the dropzone).
        if (onLauncher && event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            if (foregroundPackage != lastLauncherContentPkg) {
                lastLauncherContentPkg = foregroundPackage
                lastLauncherContentMs = 0L
            }
            val now = SystemClock.uptimeMillis()
            if (lastLauncherContentMs > 0L && now - lastLauncherContentMs < LAUNCHER_THROTTLE_MS) {
                return false
            }
            lastLauncherContentMs = now
        } else if (foregroundPackage != lastLauncherContentPkg) {
            lastLauncherContentPkg = foregroundPackage
            lastLauncherContentMs = 0L
        }

        // Scan window tree(s). Trigger if (a) a confirm/uninstall label is visible
        // AND (b) the window mentions us by name/package.
        val scanAllWindows = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP
        val blob = StringBuilder()
        var sawConfirmKeyword = false
        var sawSelfMention = false

        fun consumeRoot(root: AccessibilityNodeInfo) {
            appendTree(root, 0, blob)
            if (!sawConfirmKeyword) {
                sawConfirmKeyword = treeContainsAny(root, CONFIRMATION_KEYWORDS, 0)
            }
        }

        val roots = ArrayList<AccessibilityNodeInfo>(4)
        try {
            if (scanAllWindows) {
                val ws = try { service.windows } catch (_: Exception) { null }
                if (!ws.isNullOrEmpty()) {
                    for (w in ws) {
                        val r = try { w.root } catch (_: Exception) { null } ?: continue
                        roots.add(r)
                    }
                }
            }
            if (roots.isEmpty()) {
                val r = try { service.rootInActiveWindow } catch (_: Exception) { null }
                if (r != null) roots.add(r)
            }
            for (r in roots) consumeRoot(r)
            if (!sawSelfMention) {
                sawSelfMention = AntiUninstallHeuristics.uninstallDialogTargetsSelfFromRoot(
                    roots.firstOrNull() ?: return false
                )
            }
        } finally {
            for (r in roots) try { r.recycle() } catch (_: Exception) { }
        }

        // On installer surfaces, any self-targeting uninstall flow triggers.
        if (onInstaller) return sawSelfMention

        // On launchers, require BOTH a confirmation-style keyword visible AND
        // the app surface mentioning us. This avoids false positives when the
        // user simply has NeuroLock's icon on the home screen.
        return sawConfirmKeyword && sawSelfMention
    }

    private fun appendTree(
        node: AccessibilityNodeInfo?, depth: Int, out: StringBuilder,
    ) {
        if (node == null || depth > 40) return
        try {
            node.text?.toString()?.let { if (it.isNotBlank()) out.append(' ').append(it) }
            node.contentDescription?.toString()?.let { if (it.isNotBlank()) out.append(' ').append(it) }
        } catch (_: Exception) { }
        val n = try { node.childCount } catch (_: Exception) { 0 }
        for (i in 0 until n) {
            val c = try { node.getChild(i) } catch (_: Exception) { null } ?: continue
            appendTree(c, depth + 1, out)
        }
    }

    private fun treeContainsAny(
        node: AccessibilityNodeInfo?, needles: List<String>, depth: Int,
    ): Boolean {
        if (node == null || depth > 40) return false
        try {
            val id = node.viewIdResourceName?.lowercase() ?: ""
            val tx = node.text?.toString()?.lowercase() ?: ""
            val cd = node.contentDescription?.toString()?.lowercase() ?: ""
            for (n in needles) {
                val ln = n.lowercase()
                val idNeedle = ln.replace(' ', '_')
                if (tx.contains(ln) || cd.contains(ln) ||
                    (idNeedle.isNotBlank() && id.contains(idNeedle))
                ) return true
            }
        } catch (_: Exception) { }
        val n = try { node.childCount } catch (_: Exception) { 0 }
        for (i in 0 until n) {
            val c = try { node.getChild(i) } catch (_: Exception) { null } ?: continue
            if (treeContainsAny(c, needles, depth + 1)) return true
        }
        return false
    }
}

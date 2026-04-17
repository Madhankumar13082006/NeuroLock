package com.impulsecontrol

import android.accessibilityservice.AccessibilityService
import android.os.Build
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo

/**
 * Targeted anti-uninstall for NeuroLock.
 *
 * Philosophy: NEVER lock Settings wholesale — only when the foreground UI clearly
 * concerns *this* app (app info, uninstall, open-by-default, storage for
 * NeuroLock, etc.). Proximity matching between a self-mention and a dangerous
 * action keyword is what avoids user-irritating false positives on unrelated
 * Settings pages.
 */
object AntiUninstallHeuristics {

    /** Must match [android.defaultConfig.applicationId] in build.gradle.kts */
    private const val SELF_PACKAGE = "com.impulsecontrol"

    private const val MAX_TREE_DEPTH = 40
    private const val PROXIMITY_RADIUS = 110
    private const val SENSITIVE_THROTTLE_MS = 180L
    private const val GENERIC_THROTTLE_MS = 480L

    private val SELF_LABEL_MARKERS = listOf(
        "neurolock",
        "neuro lock",
        "neuro-lock",
        "nokkon",
        "impulsecontrol",
        "impulse control",
        "impulse-control",
    )

    private val SELF_NEEDLES: List<String> = (
        listOf(SELF_PACKAGE.lowercase()) + SELF_LABEL_MARKERS.map { it.lowercase() }
    ).distinct()

    /**
     * Surfaces that can remove the app, disable it, strip accessibility, clear
     * data, or otherwise tamper with it. Each is gated by a semantic check
     * (page actually targets us) — we NEVER block these wholesale.
     */
    val UNINSTALL_SENSITIVE_PACKAGES: Set<String> = setOf(
        // --- AOSP / Google ---
        "com.android.settings",
        "com.android.packageinstaller",
        "com.android.permissioncontroller",
        "com.android.vending",
        "com.google.android.settings",
        "com.google.android.packageinstaller",
        "com.google.android.permissioncontroller",
        "com.google.android.gms",
        "com.google.android.apps.nexuslauncher",

        // --- Samsung (OneUI) ---
        "com.samsung.android.settings",
        "com.samsung.android.packageinstaller",
        "com.samsung.android.lool",
        "com.samsung.android.sm",
        "com.samsung.android.sm_cn",
        "com.sec.android.app.launcher",
        "com.samsung.android.app.settings.bixby",
        "com.samsung.android.knox.containeragent",

        // --- Xiaomi / MIUI / HyperOS / Redmi / POCO ---
        "com.miui.packageinstaller",
        "com.miui.securitycenter",
        "com.miui.securityadd",
        "com.miui.cleanmaster",
        "com.miui.home",
        "com.xiaomi.security",
        "com.mi.android.globallauncher",

        // --- Huawei / Honor (EMUI / HarmonyOS / MagicOS) ---
        "com.huawei.systemmanager",
        "com.huawei.packageinstaller",
        "com.huawei.android.launcher",
        "com.hihonor.systemmanager",
        "com.hihonor.packageinstaller",
        "com.hihonor.android.launcher",

        // --- Oppo / Realme / OnePlus / OPlus (ColorOS / OxygenOS / RealmeUI) ---
        "com.oppo.launcher",
        "com.oppo.safe",
        "com.coloros.safecenter",
        "com.coloros.securitypermission",
        "com.coloros.phonemanager",
        "com.realme.securitycheck",
        "com.oplus.safecenter",
        "com.oplus.securitypermission",
        "com.oplus.phonemanager",
        "com.oneplus.security",
        "net.oneplus.launcher",
        "com.heytap.pictorial",

        // --- Vivo / iQOO (FunTouchOS / OriginOS) ---
        "com.vivo.permissionmanager",
        "com.vivo.safecenter",
        "com.iqoo.secure",
        "com.vivo.abe",
        "com.bbk.launcher2",

        // --- Lenovo / Motorola ---
        "com.lenovo.safecenter",
        "com.motorola.safetyhub",
        "com.motorola.launcher3",

        // --- Asus / ROG ---
        "com.asus.mobilemanager",

        // --- Nothing ---
        "com.nothing.launcher",

        // --- Transsion: Tecno / Infinix / itel ---
        "com.transsion.phonemanager",
        "com.transsion.security",

        // --- Common launchers (long-press -> app info / uninstall) ---
        "com.android.launcher",
        "com.android.launcher2",
        "com.android.launcher3",
        "com.microsoft.launcher",
        "com.teslacoilsw.launcher",
    )

    fun isSensitiveUninstallSurface(packageName: String): Boolean =
        packageName in UNINSTALL_SENSITIVE_PACKAGES

    fun isSettingsPackage(packageName: String): Boolean =
        packageName == "com.android.settings" ||
            packageName == "com.google.android.settings" ||
            packageName == "com.samsung.android.settings"

    /**
     * OEMs often split App Info / Force Stop / Uninstall across security or
     * permission apps rather than plain Settings. Treat those as Settings-like.
     */
    fun isSettingsLikeSurface(packageName: String): Boolean {
        if (packageName.isBlank()) return false
        if (isSettingsPackage(packageName)) return true
        return packageName.contains("settings") ||
            packageName.contains("securitycenter") ||
            packageName.contains("safecenter") ||
            packageName.contains("permissioncontroller") ||
            packageName.contains("permissionmanager") ||
            packageName.contains("phonemanager") ||
            packageName.contains("systemmanager") ||
            packageName.contains("mobilemanager") ||
            packageName.contains("safetyhub") ||
            packageName.contains(".secure") ||
            packageName.contains(".security") ||
            packageName.contains(".safe") ||
            packageName == "com.samsung.android.lool" ||
            packageName == "com.samsung.android.sm" ||
            packageName == "com.samsung.android.sm_cn"
    }

    fun isPackageInstallerSurface(packageName: String): Boolean =
        packageName.contains("packageinstaller") ||
            packageName == "com.google.android.permissioncontroller" ||
            packageName == "com.android.permissioncontroller"

    fun isLauncherSurface(packageName: String): Boolean =
        packageName.contains("launcher") ||
            packageName == "com.miui.home" ||
            packageName == "com.sec.android.app.launcher" ||
            packageName == "com.heytap.pictorial"

    // -------- Keywords (multilingual) --------

    /** Uninstall/remove-app phrases across locales. Bare "delete" intentionally avoided. */
    private val UNINSTALL_DIALOG_HINTS: List<String> = listOf(
        // English
        "uninstall", "remove app", "remove this app", "delete this app",
        "app will be deleted", "do you want to uninstall", "uninstall updates",
        // Hindi
        "अनइंस्टॉल", "इंस्टॉल हटाएं",
        // Spanish / Portuguese
        "desinstalar", "eliminar app", "borrar app", "excluir app",
        // French
        "désinstaller", "supprimer l'app", "supprimer l'application",
        // German
        "deinstallieren",
        // Italian
        "disinstalla",
        // Russian
        "удалить приложение",
        // Chinese
        "卸载", "解除安裝", "移除应用",
        // Japanese
        "アンインストール",
        // Korean
        "제거", "앱 삭제",
        // Arabic
        "إزالة التثبيت", "إلغاء التثبيت",
        // Turkish
        "kaldır",
        // Vietnamese
        "gỡ cài đặt",
        // Indonesian / Malay
        "copot pemasangan", "nyahpasang",
        // Thai
        "ถอนการติดตั้ง",
    )

    /** Destructive management actions in Settings / Security / Permission apps. */
    private val SETTINGS_MANAGEMENT_DANGER: List<String> = listOf(
        // English
        "uninstall", "uninstall updates", "force stop", "force-stop", "force close",
        "clear data", "clear storage", "clear cache", "disable", "turn off",
        "app info", "storage & cache", "open by default", "clear defaults",
        "remove default", "restrict",
        // Spanish
        "desinstalar", "detener", "forzar detención", "borrar datos", "deshabilitar",
        // French
        "désinstaller", "arrêt forcé", "forcer l'arrêt", "effacer les données", "désactiver",
        // German
        "deinstallieren", "stopp erzwingen", "daten löschen", "deaktivieren",
        // Italian
        "disinstalla", "arresto forzato",
        // Chinese
        "卸载", "强行停止", "强制停止", "停用", "清除数据", "清除缓存",
        // Japanese
        "アンインストール", "強制停止", "データを削除", "無効",
        // Korean
        "제거", "강제 중지", "데이터 삭제", "사용 중지",
        // Russian
        "удалить", "остановить", "принудительная остановка", "очистить данные", "отключить",
        // Arabic
        "إزالة", "فرض الإيقاف", "مسح البيانات", "تعطيل",
        // Turkish
        "kaldır", "zorla durdur", "verileri temizle", "devre dışı",
        // Vietnamese
        "gỡ cài đặt", "buộc dừng", "xóa dữ liệu", "tắt",
        // Indonesian
        "copot pemasangan", "paksa berhenti", "hapus data", "nonaktifkan",
        // Malay
        "nyahpasang",
        // Thai
        "ถอนการติดตั้ง", "บังคับหยุด", "ล้างข้อมูล", "ปิดใช้งาน",
    )

    /** Click-target labels on confirm buttons of uninstall dialogs. */
    private val UNINSTALL_CLICK_LABELS: List<String> = listOf(
        "uninstall", "ok", "confirm", "remove",
        "desinstalar", "désinstaller", "deinstallieren",
        "卸载", "アンインストール", "제거", "удалить", "確定", "确定",
    )

    // -------- Text helpers --------

    private fun windowAround(s: String, centerIdx: Int, radius: Int): String {
        val start = (centerIdx - radius).coerceAtLeast(0)
        val end = (centerIdx + radius).coerceAtMost(s.length)
        return if (start >= end) "" else s.substring(start, end)
    }

    private fun appendNodeTextTo(
        node: AccessibilityNodeInfo?,
        depth: Int,
        out: StringBuilder,
    ) {
        if (node == null || depth > MAX_TREE_DEPTH) return
        try {
            node.text?.toString()?.let { if (it.isNotBlank()) out.append(' ').append(it) }
            node.contentDescription?.toString()?.let {
                if (it.isNotBlank()) out.append(' ').append(it)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                node.hintText?.toString()?.let {
                    if (it.isNotBlank()) out.append(' ').append(it)
                }
            }
            // Resource IDs frequently leak package ("com.impulsecontrol:id/…")
            node.viewIdResourceName?.let { out.append(' ').append(it) }
        } catch (_: Exception) {
        }
        val n = try { node.childCount } catch (_: Exception) { 0 }
        for (i in 0 until n) {
            val c = try { node.getChild(i) } catch (_: Exception) { null } ?: continue
            appendNodeTextTo(c, depth + 1, out)
        }
    }

    private fun blobMentionsSelf(s: String): Boolean {
        if (s.isEmpty()) return false
        val b = s.lowercase()
        for (m in SELF_NEEDLES) {
            if (m.length >= 4 && b.contains(m)) return true
        }
        return false
    }

    private fun selfMarkerNearKeywordFlat(
        l: String,
        dangerNeedles: List<String>,
    ): Boolean {
        // Scan danger-word -> self nearby
        for (d in dangerNeedles) {
            if (d.isBlank()) continue
            val dl = d.lowercase()
            var start = 0
            while (start < l.length) {
                val i = l.indexOf(dl, start)
                if (i < 0) break
                val center = i + dl.length / 2
                val w = windowAround(l, center, PROXIMITY_RADIUS)
                if (blobMentionsSelf(w)) return true
                start = i + dl.length
            }
        }
        // Scan self -> danger-word nearby
        for (needle in SELF_NEEDLES) {
            if (needle.length < 4) continue
            var start = 0
            while (start < l.length) {
                val i = l.indexOf(needle, start)
                if (i < 0) break
                val center = i + needle.length / 2
                val w = windowAround(l, center, PROXIMITY_RADIUS)
                if (dangerNeedles.any { it.isNotBlank() && w.contains(it.lowercase()) }) return true
                start = i + needle.length
            }
        }
        return false
    }

    private fun flatHasSelfNearKeywords(flat: String, keywords: List<String>): Boolean {
        if (flat.isEmpty()) return false
        val l = flat.lowercase()
        if (!keywords.any { it.isNotBlank() && l.contains(it.lowercase()) }) return false
        if (!SELF_NEEDLES.any { it.length >= 4 && l.contains(it) }) return false
        return selfMarkerNearKeywordFlat(l, keywords)
    }

    private fun combinedUninstallTextTargetsSelf(blob: String): Boolean =
        flatHasSelfNearKeywords(blob, UNINSTALL_DIALOG_HINTS)

    private fun settingsFlatIndicatesSelfManagementDanger(blob: String): Boolean =
        flatHasSelfNearKeywords(blob, SETTINGS_MANAGEMENT_DANGER)

    // -------- Window enumeration (all windows, not just active) --------

    /**
     * Flatten text from EVERY accessibility window. Covers split-screen,
     * freeform/minimized, PIP, and floating uninstall dialogs. Callers must
     * let this function manage node recycling.
     */
    private fun collectAllWindowText(service: AccessibilityService): String {
        val sb = StringBuilder()
        val roots = ArrayList<AccessibilityNodeInfo>(4)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val windows: List<AccessibilityWindowInfo>? = try {
                    service.windows
                } catch (_: Exception) {
                    null
                }
                if (!windows.isNullOrEmpty()) {
                    for (w in windows) {
                        val r = try { w.root } catch (_: Exception) { null } ?: continue
                        roots.add(r)
                    }
                }
            }
            if (roots.isEmpty()) {
                val r = try { service.rootInActiveWindow } catch (_: Exception) { null }
                if (r != null) roots.add(r)
            }
            for (r in roots) {
                appendNodeTextTo(r, 0, sb)
                sb.append(' ')
            }
        } finally {
            for (r in roots) {
                try { r.recycle() } catch (_: Exception) { }
            }
        }
        return sb.toString()
    }

    // -------- Public: does the uninstall confirmation target us? --------

    fun uninstallDialogTargetsSelfFromRoot(root: AccessibilityNodeInfo): Boolean {
        val sb = StringBuilder()
        appendNodeTextTo(root, 0, sb)
        return combinedUninstallTextTargetsSelf(sb.toString())
    }

    fun uninstallDialogTargetsSelf(service: AccessibilityService): Boolean {
        val blob = collectAllWindowText(service)
        return combinedUninstallTextTargetsSelf(blob)
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
            try { event.className?.let { sb.append(' ').append(it) } } catch (_: Exception) { }
        } catch (_: Exception) {
        }
        val s = sb.toString()
        if (s.isBlank()) return false
        return combinedUninstallTextTargetsSelf(s)
    }

    /**
     * TYPE_VIEW_CLICKED fast path — user just tapped "Uninstall"/"OK"/"Confirm".
     * Forces an immediate window scan before the dialog can dismiss.
     */
    fun eventLooksLikeUninstallClick(event: AccessibilityEvent): Boolean {
        if (event.eventType != AccessibilityEvent.TYPE_VIEW_CLICKED) return false
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
        val l = sb.toString().lowercase()
        if (l.isBlank()) return false
        return UNINSTALL_CLICK_LABELS.any { it.length >= 2 && l.contains(it.lowercase()) }
    }

    // -------- Throttling (fast for sensitive, slow for noise) --------

    @Volatile private var uninstallThrottleMs = 0L
    @Volatile private var uninstallThrottleResult = false
    @Volatile private var uninstallThrottlePkg: String? = null

    fun uninstallDialogTargetsSelfThrottled(
        service: AccessibilityService,
        event: AccessibilityEvent,
    ): Boolean {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            uninstallThrottleMs = 0L
            uninstallThrottleResult = false
            uninstallThrottlePkg = null
        }
        // Fast path 1: event text alone reveals the target
        if (eventLooksLikeUninstallOfSelf(event)) return true
        // Fast path 2: tap on uninstall button — immediate window scan, no throttle
        if (eventLooksLikeUninstallClick(event)) {
            return uninstallDialogTargetsSelf(service)
        }
        // Non-noise events -> scan now
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
        if (uninstallThrottleMs > 0L && now - uninstallThrottleMs < SENSITIVE_THROTTLE_MS) {
            return uninstallThrottleResult
        }
        uninstallThrottleMs = now
        val r = uninstallDialogTargetsSelf(service)
        uninstallThrottleResult = r
        return r
    }

    /**
     * Arm anti-uninstall logic for the given foreground package.
     * - Package installers / Play Store / launchers: look for uninstall+self proximity
     * - Settings-like surfaces: look for management-action+self proximity
     */
    fun shouldArmAntiUninstallForSensitivePackage(
        service: AccessibilityService,
        event: AccessibilityEvent,
        packageName: String,
    ): Boolean {
        val sensitive = isSensitiveUninstallSurface(packageName)
        val settingsLike = isSettingsLikeSurface(packageName)
        if (!sensitive && !settingsLike) return false

        if (isPackageInstallerSurface(packageName) ||
            packageName == "com.android.vending" ||
            isLauncherSurface(packageName)
        ) {
            return uninstallDialogTargetsSelfThrottled(service, event)
        }
        if (settingsLike) {
            return shouldStartSettingsLockdown(service, event)
        }
        return false
    }

    // -------- "Current window mentions us" (for PIN gate) --------

    fun shouldRequirePinForCurrentWindow(
        service: AccessibilityService,
        event: AccessibilityEvent,
    ): Boolean {
        if (quickEventFieldsMatch(event)) return true
        // Check all windows (split-screen / freeform / PIP / floating dialog)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val windows = try { service.windows } catch (_: Exception) { null }
            if (!windows.isNullOrEmpty()) {
                for (w in windows) {
                    val r = try { w.root } catch (_: Exception) { null } ?: continue
                    try {
                        if (treeMentionsSelf(r, 0)) return true
                    } finally {
                        try { r.recycle() } catch (_: Exception) { }
                    }
                }
                return false
            }
        }
        val root = try { service.rootInActiveWindow } catch (_: Exception) { null } ?: return false
        return try {
            treeMentionsSelf(root, 0)
        } finally {
            try { root.recycle() } catch (_: Exception) { }
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
            event.contentDescription?.let { if (blobMentionsSelf(it.toString())) return true }
            try {
                event.className?.toString()?.let { if (blobMentionsSelf(it)) return true }
            } catch (_: Exception) { }
        } catch (_: Exception) {
        }
        return false
    }

    private fun treeMentionsSelf(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > MAX_TREE_DEPTH) return false
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
        val n = try { node.childCount } catch (_: Exception) { 0 }
        for (i in 0 until n) {
            val c = try { node.getChild(i) } catch (_: Exception) { null } ?: continue
            if (treeMentionsSelf(c, depth + 1)) return true
        }
        return false
    }

    @Volatile private var lastContentTreeMs = 0L
    @Volatile private var lastContentTreeResult = false
    @Volatile private var lastContentThrottlePkg: String? = null

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
        if (pkg != lastContentThrottlePkg) {
            lastContentThrottlePkg = pkg
            lastContentTreeMs = 0L
            lastContentTreeResult = false
        }
        val now = SystemClock.uptimeMillis()
        val throttle =
            if (isSensitiveUninstallSurface(pkg) || isSettingsLikeSurface(pkg))
                SENSITIVE_THROTTLE_MS
            else
                GENERIC_THROTTLE_MS
        if (lastContentTreeMs > 0L && now - lastContentTreeMs < throttle) {
            return lastContentTreeResult
        }
        lastContentTreeMs = now
        val r = shouldRequirePinForCurrentWindow(service, event)
        lastContentTreeResult = r
        return r
    }

    /**
     * True when the current Settings UI shows destructive management actions for
     * NeuroLock (uninstall, force stop, clear data, disable, …). Proximity-gated
     * so unrelated app info pages that merely mention NeuroLock in a list do not
     * trip the lockdown.
     */
    fun shouldStartSettingsLockdown(
        service: AccessibilityService,
        event: AccessibilityEvent,
    ): Boolean {
        val pkg = event.packageName?.toString() ?: return false
        if (!isSettingsLikeSurface(pkg)) return false
        val blob = collectAllWindowText(service)
        if (blob.isBlank()) return false
        return settingsFlatIndicatesSelfManagementDanger(blob) ||
            combinedUninstallTextTargetsSelf(blob)
    }
}
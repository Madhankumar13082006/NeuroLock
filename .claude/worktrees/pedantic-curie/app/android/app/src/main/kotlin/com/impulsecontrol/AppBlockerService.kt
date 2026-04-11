package com.impulsecontrol

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import io.flutter.embedding.android.FlutterActivity

class AppBlockerService : AccessibilityService() {

    companion object {
        private var blockedPackages = mutableSetOf(
            "com.instagram.android",
            "com.google.android.youtube",
            "com.zhiliaoapp.musically"
        )
        private var lastTriggered = ""
        private var lastTime = 0L
        private val restrictedPackages = setOf(
            "com.google.android.packageinstaller",
            "com.android.packageinstaller",
            "com.miui.packageinstaller",
            "com.samsung.android.packageinstaller",
            "com.android.settings"
        )

        fun updateBlockedApps(packages: List<String>) {
            blockedPackages = packages.toMutableSet()
        }

        fun isEnabled(context: Context): Boolean {
            val prefString = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            return prefString.contains(context.packageName)
        }
    }

    private val PREFS = "impulse_control"
    private val KEY_UNLOCK_UNTIL = "unlock_until_ms"
    private val KEY_PIN_SET = "pin_set"

    override fun onServiceConnected() {
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 100
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return

        // If currently in an unlock window, don't block.
        val unlockUntil = getSharedPreferences(PREFS, MODE_PRIVATE).getLong(KEY_UNLOCK_UNTIL, 0L)
        val pinSet = getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean(KEY_PIN_SET, false)
        val unlocked = unlockUntil > System.currentTimeMillis()

        val protectEnabled = pinSet && blockedPackages.isNotEmpty()
        val isBlockedTarget = pkg in blockedPackages
        val isRestrictedAction = protectEnabled && pkg in restrictedPackages
        if (!isBlockedTarget && !isRestrictedAction) return
        if (unlocked) return

        val now = System.currentTimeMillis()
        if (pkg == lastTriggered && now - lastTime < 3000) return
        lastTriggered = pkg
        lastTime = now

        // Launch Flutter overlay screen via deep link intent
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            // This must match GoRouter's nested path.
            putExtra("route", "/home/lock/$pkg")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        startActivity(intent)
    }

    override fun onInterrupt() {}
}

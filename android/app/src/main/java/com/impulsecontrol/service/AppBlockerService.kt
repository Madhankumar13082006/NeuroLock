package com.impulsecontrol.service

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import com.impulsecontrol.ui.LockOverlayActivity

class AppBlockerService : AccessibilityService() {

    private val blockedPackages = setOf(
        "com.instagram.android",
        "com.google.android.youtube"
    )

    private var lastTriggeredPackage: String? = null
    private var lastTriggerTime = 0L

    override fun onServiceConnected() {
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 100
        }
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val packageName = event.packageName?.toString() ?: return

        if (packageName !in blockedPackages) return

        val now = System.currentTimeMillis()
        if (packageName == lastTriggeredPackage && now - lastTriggerTime < 3000) return

        lastTriggeredPackage = packageName
        lastTriggerTime = now

        val intent = Intent(this, LockOverlayActivity::class.java).apply {
            putExtra("packageName", packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(intent)
    }

    override fun onInterrupt() {}
}

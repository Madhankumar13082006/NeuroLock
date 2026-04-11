package com.impulsecontrol

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

/**
 * OverlayService - handles display of overlay windows if needed
 * For now, we're using Flutter's native overlay which doesn't require
 * a separate Android overlay service
 */
class OverlayService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}
}

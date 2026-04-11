package com.impulsecontrol

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

/**
 * Placeholder second accessibility entry (manifest). The real UX is a
 * full-screen Flutter route: [MainActivity] + `/lock/:packageName` from
 * [AppBlockerService] (same as a draw-over-app overlay for PIN / wait flow).
 */
class OverlayService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}
}

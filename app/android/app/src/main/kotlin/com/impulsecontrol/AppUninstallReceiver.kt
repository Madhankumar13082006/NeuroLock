package com.impulsecontrol

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * PACKAGE_REMOVED cannot be cancelled from a normal app; uninstall prevention
 * is handled by [AppBlockerService] (Settings, installers, Play Store, etc.).
 * This receiver is kept for diagnostics only.
 */
class AppUninstallReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != Intent.ACTION_PACKAGE_REMOVED) return
        val removed = intent.data?.schemeSpecificPart ?: return
        val self = context?.packageName ?: return
        if (removed == self && !intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)) {
            // App process is already tearing down; nothing reliable to do here.
        }
    }
}

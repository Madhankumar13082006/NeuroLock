package com.impulsecontrol

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Diagnostics only — a normal app cannot cancel PACKAGE_REMOVED. Real
 * uninstall prevention lives in [AppBlockerService] (it turns the user
 * away before the uninstall dialog can commit).
 *
 * This receiver fires for other packages too; we only log our own and
 * ignore app-update replacements.
 */
class AppUninstallReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_PACKAGE_REMOVED &&
            action != Intent.ACTION_PACKAGE_FULLY_REMOVED
        ) return

        val removed = intent.data?.schemeSpecificPart ?: return
        val self = context?.packageName ?: return
        if (removed != self) return
        if (intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)) return

        // App process is tearing down; nothing here can stop it.
        // Log so a remote diagnostic can tell a bypass happened.
        try {
            Log.w("NeuroLockUninstall", "Self uninstall broadcast observed: action=$action pkg=$removed")
        } catch (_: Throwable) { }
    }
}

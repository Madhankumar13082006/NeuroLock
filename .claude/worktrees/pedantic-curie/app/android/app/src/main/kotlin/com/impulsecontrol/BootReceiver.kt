package com.impulsecontrol

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            // App blocking service will start when user enables it in accessibility settings
            // This receiver ensures we're ready to listen
        }
    }
}

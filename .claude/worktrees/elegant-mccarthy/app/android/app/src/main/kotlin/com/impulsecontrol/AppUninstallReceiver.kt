package com.impulsecontrol

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

class AppUninstallReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Intent.ACTION_PACKAGE_REMOVED) {
            val packageName = intent.data?.schemeSpecificPart
            
            // Prevent uninstall of our app
            if (packageName == "com.impulsecontrol") {
                abortBroadcast()
                
                // Optionally show a notification
                context?.showNotification(
                    title = "Uninstall Blocked",
                    message = "Cannot uninstall while blocks are active. Disable all blocks first.",
                    context = context
                )
            }
        }
    }
    
    private fun Context.showNotification(title: String, message: String, context: Context) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) 
            as android.app.NotificationManager
        
        val channelId = "impulse_control_channel"
        
        // Create notification channel for Android 8+
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                channelId,
                "Impulse Control",
                android.app.NotificationManager.IMPORTANCE_HIGH
            )
            notificationManager.createNotificationChannel(channel)
        }
        
        val notification = android.app.Notification.Builder(context, channelId)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setAutoCancel(true)
            .build()
            
        notificationManager.notify(999, notification)
    }
}

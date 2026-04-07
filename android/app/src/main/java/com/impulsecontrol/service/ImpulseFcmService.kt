package com.impulsecontrol.service

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.impulsecontrol.R
import com.impulsecontrol.api.RetrofitClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class ImpulseFcmService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val approvalUrl = message.data["approvalUrl"] ?: return
        val appName = message.data["appName"] ?: "an app"
        val userEmail = message.data["userEmail"] ?: "Someone"

        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(approvalUrl))
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, ImpulseForegroundService.CHANNEL_ID)
            .setContentTitle("Unlock Request")
            .setContentText("$userEmail wants to open $appName")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(System.currentTimeMillis().toInt(), notification)
    }

    override fun onNewToken(token: String) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                RetrofitClient.updateFcmToken(token)
            } catch (_: Exception) {}
        }
    }
}

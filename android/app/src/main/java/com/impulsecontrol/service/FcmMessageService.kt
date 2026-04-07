package com.impulsecontrol.service

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.impulsecontrol.R

class FcmMessageService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        val title = remoteMessage.notification?.title ?: "Impulse Control"
        val body = remoteMessage.notification?.body ?: "New notification"
        val requestId = remoteMessage.data["requestId"]
        val status = remoteMessage.data["status"]

        sendNotification(title, body, requestId, status)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Send token to backend
        saveTokenToBackend(token)
    }

    private fun sendNotification(title: String, body: String, requestId: String?, status: String?) {
        val notificationId = (System.currentTimeMillis() % 10000).toInt()

        val channel = "unlock_requests"
        val channelName = "Unlock Requests"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationChannel = NotificationChannel(
                channel,
                channelName,
                NotificationManager.IMPORTANCE_HIGH
            )
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(notificationChannel)
        }

        val notification = NotificationCompat.Builder(this, channel)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, notification)
    }

    private fun saveTokenToBackend(token: String) {
        // TODO: Call backend API to update FCM token
        // PUT /user/fcm-token with { fcmToken: token }
    }
}

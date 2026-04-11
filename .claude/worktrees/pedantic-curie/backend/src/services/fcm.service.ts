import admin from 'firebase-admin';
import '../config/firebaseAdmin';

export async function sendApprovalNotification(
  fcmToken: string,
  approvalToken: string,
  appName: string,
  userEmail: string
) {
  const approvalUrl = `${process.env.APPROVAL_BASE_URL}/approve/${approvalToken}`;

  await admin.messaging().send({
    token: fcmToken,
    notification: {
      title: 'Unlock Request',
      body: `${userEmail} wants to open ${appName}. Approve or deny?`,
    },
    data: {
      approvalUrl,
      appName,
      userEmail,
    },
  });
}
import admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    }),
  });
}

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
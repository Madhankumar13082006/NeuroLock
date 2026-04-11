"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendApprovalNotification = sendApprovalNotification;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
require("../config/firebaseAdmin");
async function sendApprovalNotification(fcmToken, approvalToken, appName, userEmail) {
    const approvalUrl = `${process.env.APPROVAL_BASE_URL}/approve/${approvalToken}`;
    await firebase_admin_1.default.messaging().send({
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

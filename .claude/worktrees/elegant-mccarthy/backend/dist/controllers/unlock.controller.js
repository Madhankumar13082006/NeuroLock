"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requestUnlock = requestUnlock;
exports.unlockStatus = unlockStatus;
const zod_1 = require("zod");
const unlock_service_1 = require("../services/unlock.service");
const database_1 = require("../config/database");
const fcm_service_1 = require("../services/fcm.service");
const requestSchema = zod_1.z.object({ packageName: zod_1.z.string().min(3) });
async function requestUnlock(req, res) {
    try {
        const { packageName } = requestSchema.parse(req.body);
        const userId = req.userId;
        const { existing, request } = await (0, unlock_service_1.createUnlockRequest)(userId, packageName);
        if (existing)
            return res.json({ message: 'Request already active', request });
        // Get trusted contacts + send notifications
        const contacts = await database_1.pool.query(`SELECT tc.*, u.fcm_token, u.email
       FROM trusted_contacts tc
       JOIN users u ON u.id = tc.user_id
       WHERE tc.user_id = $1`, [userId]);
        for (const contact of contacts.rows) {
            // Create approval token for each contact
            const tokenResult = await database_1.pool.query(`INSERT INTO approval_tokens (unlock_request_id, contact_id)
         VALUES ($1, $2) RETURNING token`, [request.id, contact.id]);
            const approvalToken = tokenResult.rows[0].token;
            if (contact.fcm_token) {
                await (0, fcm_service_1.sendApprovalNotification)(contact.fcm_token, approvalToken, packageName, contact.email);
            }
        }
        // Update status to WAITING
        await database_1.pool.query("UPDATE unlock_requests SET status = 'WAITING' WHERE id = $1", [request.id]);
        res.status(201).json({ requestId: request.id, status: 'WAITING' });
    }
    catch (err) {
        res.status(400).json({ error: err.message });
    }
}
async function unlockStatus(req, res) {
    try {
        const status = await (0, unlock_service_1.getUnlockStatus)(req.params.id, req.userId);
        res.json(status);
    }
    catch (err) {
        res.status(404).json({ error: err.message });
    }
}

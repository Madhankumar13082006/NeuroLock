"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getProfile = getProfile;
exports.updateFcmToken = updateFcmToken;
const zod_1 = require("zod");
const database_1 = require("../config/database");
const fcmSchema = zod_1.z.object({ fcmToken: zod_1.z.string().min(10) });
async function getProfile(req, res) {
    try {
        const result = await database_1.pool.query('SELECT id, email, created_at FROM users WHERE id = $1', [req.userId]);
        res.json(result.rows[0]);
    }
    catch (err) {
        res.status(500).json({ error: err.message });
    }
}
async function updateFcmToken(req, res) {
    try {
        const { fcmToken } = fcmSchema.parse(req.body);
        await database_1.pool.query('UPDATE users SET fcm_token = $1 WHERE id = $2', [fcmToken, req.userId]);
        res.json({ success: true });
    }
    catch (err) {
        res.status(400).json({ error: err.message });
    }
}

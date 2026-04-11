"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createUnlockRequest = createUnlockRequest;
exports.getUnlockStatus = getUnlockStatus;
const database_1 = require("../config/database");
const queue_1 = require("../jobs/queue");
async function createUnlockRequest(userId, packageName) {
    // Prevent duplicate active requests
    const existing = await database_1.pool.query(`SELECT id FROM unlock_requests
     WHERE user_id = $1 AND package_name = $2
     AND status IN ('REQUESTED','WAITING','APPROVED','UNLOCKED','FALLBACK')`, [userId, packageName]);
    if (existing.rows.length > 0) {
        return { existing: true, request: existing.rows[0] };
    }
    // Rate limit: max 5 requests per hour
    const hourAgo = new Date(Date.now() - 3600000);
    const recent = await database_1.pool.query('SELECT COUNT(*) FROM unlock_requests WHERE user_id = $1 AND requested_at > $2', [userId, hourAgo]);
    if (parseInt(recent.rows[0].count) >= 5) {
        throw new Error('Rate limit exceeded. Max 5 requests per hour.');
    }
    const result = await database_1.pool.query(`INSERT INTO unlock_requests (user_id, package_name, status)
     VALUES ($1, $2, 'REQUESTED') RETURNING *`, [userId, packageName]);
    const request = result.rows[0];
    // Schedule fallback job for 20 minutes (if queue available)
    if (queue_1.unlockQueue) {
        const job = await queue_1.unlockQueue.add('fallback', { requestId: request.id }, { delay: parseInt(process.env.FALLBACK_DELAY_MS || '1200000') });
        // Store job id for potential cancellation
        await database_1.pool.query('UPDATE unlock_requests SET fallback_job_id = $1 WHERE id = $2', [job.id, request.id]);
    }
    return { existing: false, request };
}
async function getUnlockStatus(requestId, userId) {
    const result = await database_1.pool.query('SELECT * FROM unlock_requests WHERE id = $1 AND user_id = $2', [requestId, userId]);
    if (result.rows.length === 0)
        throw new Error('Not found');
    return result.rows[0];
}

"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.fallbackWorker = exports.unlockQueue = void 0;
const bullmq_1 = require("bullmq");
const redis_1 = require("../config/redis");
const database_1 = require("../config/database");
let unlockQueue = null;
exports.unlockQueue = unlockQueue;
let fallbackWorker = null;
exports.fallbackWorker = fallbackWorker;
// Initialize queue only if Redis is available
try {
    if (redis_1.redis.status === 'ready' || redis_1.redis.status === 'connecting') {
        exports.unlockQueue = unlockQueue = new bullmq_1.Queue('unlock', { connection: redis_1.redis });
        // Fallback job: auto-unlock after 20 min if no approval
        exports.fallbackWorker = fallbackWorker = new bullmq_1.Worker('unlock', async (job) => {
            if (job.name === 'fallback') {
                const { requestId } = job.data;
                const result = await database_1.pool.query(`UPDATE unlock_requests
           SET status = 'FALLBACK', unlocked_at = NOW(),
               expires_at = NOW() + INTERVAL '30 minutes'
           WHERE id = $1 AND status IN ('REQUESTED','WAITING')
           RETURNING id`, [requestId]);
                if (result.rows.length > 0) {
                    // Schedule expiry job
                    if (unlockQueue) {
                        await unlockQueue.add('expire', { requestId }, { delay: parseInt(process.env.UNLOCK_DURATION_MS || '1800000') });
                    }
                }
            }
            if (job.name === 'expire') {
                const { requestId } = job.data;
                await database_1.pool.query(`UPDATE unlock_requests SET status = 'EXPIRED'
           WHERE id = $1 AND status IN ('UNLOCKED','APPROVED','FALLBACK')`, [requestId]);
            }
        }, { connection: redis_1.redis });
    }
}
catch (err) {
    console.warn('Redis not available, queue workers disabled:', err.message);
}

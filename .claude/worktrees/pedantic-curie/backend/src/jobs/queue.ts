import { Queue, Worker, Job } from 'bullmq';
import { redis } from '../config/redis';
import { pool } from '../config/database';

let unlockQueue: Queue | null = null;
let fallbackWorker: Worker | null = null;

// Initialize queue only if Redis is available
try {
  if (redis.status === 'ready' || redis.status === 'connecting') {
    unlockQueue = new Queue('unlock', { connection: redis });

    // Fallback job: auto-unlock after 20 min if no approval
    fallbackWorker = new Worker('unlock', async (job: Job) => {
      if (job.name === 'fallback') {
        const { requestId } = job.data;
        const result = await pool.query(
          `UPDATE unlock_requests
           SET status = 'FALLBACK', unlocked_at = NOW(),
               expires_at = NOW() + INTERVAL '30 minutes'
           WHERE id = $1 AND status IN ('REQUESTED','WAITING')
           RETURNING id`,
          [requestId]
        );
        if (result.rows.length > 0) {
          // Schedule expiry job
          if (unlockQueue) {
            await unlockQueue.add(
              'expire',
              { requestId },
              { delay: parseInt(process.env.UNLOCK_DURATION_MS || '1800000') }
            );
          }
        }
      }

      if (job.name === 'expire') {
        const { requestId } = job.data;
        await pool.query(
          `UPDATE unlock_requests SET status = 'EXPIRED'
           WHERE id = $1 AND status IN ('UNLOCKED','APPROVED','FALLBACK')`,
          [requestId]
        );
      }
    }, { connection: redis });
  }
} catch (err) {
  console.warn('Redis not available, queue workers disabled:', (err as Error).message);
}

export { unlockQueue, fallbackWorker };
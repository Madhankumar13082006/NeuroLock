import { pool } from '../config/database';
import { unlockQueue } from '../jobs/queue';

export async function getApprovalInfo(token: string) {
  const result = await pool.query(
    `SELECT at.*, ur.package_name, ur.status, u.email as user_email
     FROM approval_tokens at
     JOIN unlock_requests ur ON ur.id = at.unlock_request_id
     JOIN users u ON u.id = ur.user_id
     WHERE at.token = $1`,
    [token]
  );
  if (result.rows.length === 0) throw new Error('Invalid token');

  const row = result.rows[0];
  if (row.used) throw new Error('Token already used');
  if (new Date(row.expires_at) < new Date()) throw new Error('Token expired');
  if (!['REQUESTED', 'WAITING'].includes(row.status)) throw new Error('Request no longer pending');

  return row;
}

export async function processApproval(token: string, decision: 'approve' | 'deny') {
  const info = await getApprovalInfo(token);

  // Mark token as used (single-use enforcement)
  await pool.query('UPDATE approval_tokens SET used = TRUE WHERE token = $1', [token]);

  const newStatus = decision === 'approve' ? 'APPROVED' : 'DENIED';

  const result = await pool.query(
    `UPDATE unlock_requests
     SET status = $1,
         unlocked_at = CASE WHEN $1 = 'APPROVED' THEN NOW() ELSE NULL END,
         expires_at = CASE WHEN $1 = 'APPROVED' THEN NOW() + INTERVAL '30 minutes' ELSE NULL END
     WHERE id = $2 RETURNING *`,
    [newStatus, info.unlock_request_id]
  );

  if (decision === 'approve') {
    // Cancel the fallback job
    if (unlockQueue && result.rows[0].fallback_job_id) {
      const job = await unlockQueue.getJob(result.rows[0].fallback_job_id);
      if (job) await job.remove();
    }
    // Schedule expiry
    if (unlockQueue) {
      await unlockQueue.add(
        'expire',
        { requestId: info.unlock_request_id },
        { delay: parseInt(process.env.UNLOCK_DURATION_MS || '1800000') }
      );
    }
  }

  return result.rows[0];
}
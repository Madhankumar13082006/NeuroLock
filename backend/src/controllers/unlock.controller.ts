import { Response } from 'express';
import { z } from 'zod';
import { AuthRequest } from '../middleware/auth.middleware';
import { createUnlockRequest, getUnlockStatus } from '../services/unlock.service';
import { pool } from '../config/database';
import { sendApprovalNotification } from '../services/fcm.service';

const requestSchema = z.object({ packageName: z.string().min(3) });

export async function requestUnlock(req: AuthRequest, res: Response) {
  try {
    const { packageName } = requestSchema.parse(req.body);
    const userId = req.userId!;

    const { existing, request } = await createUnlockRequest(userId, packageName);
    if (existing) return res.json({ message: 'Request already active', request });

    // Get trusted contacts + send notifications
    const contacts = await pool.query(
      `SELECT tc.*, u.fcm_token, u.email
       FROM trusted_contacts tc
       JOIN users u ON u.id = tc.user_id
       WHERE tc.user_id = $1`, [userId]
    );

    for (const contact of contacts.rows) {
      // Create approval token for each contact
      const tokenResult = await pool.query(
        `INSERT INTO approval_tokens (unlock_request_id, contact_id)
         VALUES ($1, $2) RETURNING token`,
        [request.id, contact.id]
      );
      const approvalToken = tokenResult.rows[0].token;

      if (contact.fcm_token) {
        await sendApprovalNotification(
          contact.fcm_token,
          approvalToken,
          packageName,
          contact.email
        );
      }
    }

    // Update status to WAITING
    await pool.query(
      "UPDATE unlock_requests SET status = 'WAITING' WHERE id = $1",
      [request.id]
    );

    res.status(201).json({ requestId: request.id, status: 'WAITING' });
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
}

export async function unlockStatus(req: AuthRequest, res: Response) {
  try {
    const status = await getUnlockStatus(req.params.id as string, req.userId!);
    res.json(status);
  } catch (err: any) {
    res.status(404).json({ error: err.message });
  }
}
import { Response } from 'express';
import { z } from 'zod';
import { AuthRequest } from '../middleware/auth.middleware';
import { pool } from '../config/database';

const fcmSchema = z.object({ fcmToken: z.string().min(10) });

export async function getProfile(req: AuthRequest, res: Response) {
  try {
    const result = await pool.query(
      'SELECT id, email, created_at FROM users WHERE id = $1',
      [req.userId]
    );
    res.json(result.rows[0]);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function updateFcmToken(req: AuthRequest, res: Response) {
  try {
    const { fcmToken } = fcmSchema.parse(req.body);
    await pool.query('UPDATE users SET fcm_token = $1 WHERE id = $2', [fcmToken, req.userId]);
    res.json({ success: true });
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
}

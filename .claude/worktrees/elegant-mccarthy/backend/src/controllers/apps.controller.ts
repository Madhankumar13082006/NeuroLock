import { Response } from 'express';
import { z } from 'zod';
import { AuthRequest } from '../middleware/auth.middleware';
import { pool } from '../config/database';

const appSchema = z.object({
  packageName: z.string().min(3),
  appName: z.string().optional(),
});

export async function addBlockedApp(req: AuthRequest, res: Response) {
  try {
    const { packageName, appName } = appSchema.parse(req.body);
    const result = await pool.query(
      `INSERT INTO blocked_apps (user_id, package_name, app_name)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, package_name) DO NOTHING
       RETURNING *`,
      [req.userId, packageName, appName ?? packageName]
    );
    res.status(201).json(result.rows[0] ?? { message: 'Already blocked' });
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
}

export async function listBlockedApps(req: AuthRequest, res: Response) {
  try {
    const result = await pool.query(
      'SELECT * FROM blocked_apps WHERE user_id = $1',
      [req.userId]
    );
    res.json(result.rows);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function removeBlockedApp(req: AuthRequest, res: Response) {
  try {
    await pool.query(
      'DELETE FROM blocked_apps WHERE id = $1 AND user_id = $2',
      [req.params.id as string, req.userId]
    );
    res.json({ success: true });
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
}

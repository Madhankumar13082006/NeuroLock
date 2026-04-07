import { Response } from 'express';
import { z } from 'zod';
import { AuthRequest } from '../middleware/auth.middleware';
import { pool } from '../config/database';

const contactSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
});

export async function addContact(req: AuthRequest, res: Response) {
  try {
    const { name, email } = contactSchema.parse(req.body);
    const result = await pool.query(
      'INSERT INTO trusted_contacts (user_id, name, email) VALUES ($1, $2, $3) RETURNING *',
      [req.userId, name, email]
    );
    res.status(201).json(result.rows[0]);
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
}

export async function listContacts(req: AuthRequest, res: Response) {
  try {
    const result = await pool.query(
      'SELECT * FROM trusted_contacts WHERE user_id = $1 ORDER BY created_at DESC',
      [req.userId]
    );
    res.json(result.rows);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function deleteContact(req: AuthRequest, res: Response) {
  try {
    await pool.query(
      'DELETE FROM trusted_contacts WHERE id = $1 AND user_id = $2',
      [req.params.id as string, req.userId]
    );
    res.json({ success: true });
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
}

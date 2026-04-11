import { Request, Response } from 'express';
import { z } from 'zod';
import { registerUser, loginUser } from '../services/auth.service';

const schema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

export async function register(req: Request, res: Response) {
  try {
    const { email, password } = schema.parse(req.body);
    const user = await registerUser(email, password);
    res.status(201).json({ user });
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
}

export async function login(req: Request, res: Response) {
  try {
    const { email, password } = schema.parse(req.body);
    const tokens = await loginUser(email, password);
    res.json(tokens);
  } catch (err: any) {
    res.status(401).json({ error: err.message });
  }
}
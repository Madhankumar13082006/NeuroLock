import { Request, Response } from 'express';
import {
  getSetupInfo,
  setupTrustedPin,
  verifyTrustedPin,
} from '../services/trustedPin.service';

export async function getTrustedSetup(req: Request, res: Response) {
  try {
    const info = await getSetupInfo(req.params.token as string);
    res.json(info);
  } catch (err: any) {
    res.status(400).json({ error: err.message || 'Invalid setup link' });
  }
}

export async function postTrustedSetup(req: Request, res: Response) {
  try {
    const { trustedName, pin } = req.body as {
      trustedName: string;
      pin: string;
    };
    await setupTrustedPin(req.params.token as string, trustedName, pin);
    res.json({ ok: true });
  } catch (err: any) {
    res.status(400).json({ error: err.message || 'Failed to set trusted PIN' });
  }
}

export async function postVerifyTrustedPin(req: Request, res: Response) {
  try {
    const { idToken, pin } = req.body as { idToken: string; pin: string };
    const out = await verifyTrustedPin(idToken, pin);
    if (!out.ok) return res.status(401).json({ ok: false, error: 'Invalid PIN' });
    res.json(out);
  } catch (err: any) {
    res.status(400).json({ error: err.message || 'Failed to verify PIN' });
  }
}


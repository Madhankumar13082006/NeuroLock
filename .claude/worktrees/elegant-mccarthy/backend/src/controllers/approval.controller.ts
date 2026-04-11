import { Request, Response } from 'express';
import { getApprovalInfo, processApproval } from '../services/approval.service';

export async function getApprovalPage(req: Request, res: Response) {
  try {
    const info = await getApprovalInfo(req.params.token as string);
    res.json({
      appName: info.package_name,
      userEmail: info.user_email,
      token: req.params.token,
    });
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
}

export async function submitApproval(req: Request, res: Response) {
  try {
    const { decision } = req.body as { decision: 'approve' | 'deny' };
    if (!['approve', 'deny'].includes(decision)) {
      return res.status(400).json({ error: 'Invalid decision' });
    }
    const result = await processApproval(req.params.token as string, decision);
    res.json({ status: result.status });
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
}
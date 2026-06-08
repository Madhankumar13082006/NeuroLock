import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { register, login } from '../controllers/auth.controller';
import { requestUnlock, unlockStatus } from '../controllers/unlock.controller';
import { getApprovalPage, submitApproval } from '../controllers/approval.controller';
import { addContact, listContacts, deleteContact } from '../controllers/contacts.controller';
import { addBlockedApp, listBlockedApps, removeBlockedApp } from '../controllers/apps.controller';
import { getProfile, updateFcmToken } from '../controllers/user.controller';
import { authMiddleware } from '../middleware/auth.middleware';
import {
  getTrustedSetup,
  postTrustedSetup,
  postVerifyTrustedPin,
} from '../controllers/trustedPin.controller';
import { getInvitePinPage } from '../controllers/invitePage.controller';

const router = Router();

const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 20 });
const unlockLimiter = rateLimit({ windowMs: 60 * 60 * 1000, max: 10 });

router.get('/', (req, res) => {
  res.json({ status: 'OK', message: 'Impulse Control API running' });
});

router.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
  });
});

// Auth
router.post('/auth/register', authLimiter, register);
router.post('/auth/login', authLimiter, login);

// User
router.get('/user/profile', authMiddleware, getProfile);
router.put('/user/fcm-token', authMiddleware, updateFcmToken);

// Trusted contacts
router.post('/contacts', authMiddleware, addContact);
router.get('/contacts', authMiddleware, listContacts);
router.delete('/contacts/:id', authMiddleware, deleteContact);

// Blocked apps
router.post('/apps/blocked', authMiddleware, addBlockedApp);
router.get('/apps/blocked', authMiddleware, listBlockedApps);
router.delete('/apps/blocked/:id', authMiddleware, removeBlockedApp);

// Unlock
router.post('/unlock/request', authMiddleware, unlockLimiter, requestUnlock);
router.get('/unlock/status/:id', authMiddleware, unlockStatus);

// Approval (no auth — token-based)
router.get('/approve/:token', getApprovalPage);
router.post('/approve/:token', submitApproval);

// Trusted PIN setup + verification
router.get('/trusted/setup/:token', getTrustedSetup);
router.post('/trusted/setup/:token', postTrustedSetup);
router.post('/trusted/verify-pin', postVerifyTrustedPin);

// Browser PIN page (local LAN): http://<PC_IP>:3000/invite/<token>
router.get('/invite/:token', getInvitePinPage);

export default router;
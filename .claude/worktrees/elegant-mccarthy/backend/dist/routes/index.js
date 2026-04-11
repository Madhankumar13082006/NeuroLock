"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const express_rate_limit_1 = __importDefault(require("express-rate-limit"));
const auth_controller_1 = require("../controllers/auth.controller");
const unlock_controller_1 = require("../controllers/unlock.controller");
const approval_controller_1 = require("../controllers/approval.controller");
const contacts_controller_1 = require("../controllers/contacts.controller");
const apps_controller_1 = require("../controllers/apps.controller");
const user_controller_1 = require("../controllers/user.controller");
const auth_middleware_1 = require("../middleware/auth.middleware");
const trustedPin_controller_1 = require("../controllers/trustedPin.controller");
const router = (0, express_1.Router)();
const authLimiter = (0, express_rate_limit_1.default)({ windowMs: 15 * 60 * 1000, max: 20 });
const unlockLimiter = (0, express_rate_limit_1.default)({ windowMs: 60 * 60 * 1000, max: 10 });
router.get('/', (req, res) => {
    res.json({ status: 'OK', message: 'Impulse Control API running' });
});
// Auth
router.post('/auth/register', authLimiter, auth_controller_1.register);
router.post('/auth/login', authLimiter, auth_controller_1.login);
// User
router.get('/user/profile', auth_middleware_1.authMiddleware, user_controller_1.getProfile);
router.put('/user/fcm-token', auth_middleware_1.authMiddleware, user_controller_1.updateFcmToken);
// Trusted contacts
router.post('/contacts', auth_middleware_1.authMiddleware, contacts_controller_1.addContact);
router.get('/contacts', auth_middleware_1.authMiddleware, contacts_controller_1.listContacts);
router.delete('/contacts/:id', auth_middleware_1.authMiddleware, contacts_controller_1.deleteContact);
// Blocked apps
router.post('/apps/blocked', auth_middleware_1.authMiddleware, apps_controller_1.addBlockedApp);
router.get('/apps/blocked', auth_middleware_1.authMiddleware, apps_controller_1.listBlockedApps);
router.delete('/apps/blocked/:id', auth_middleware_1.authMiddleware, apps_controller_1.removeBlockedApp);
// Unlock
router.post('/unlock/request', auth_middleware_1.authMiddleware, unlockLimiter, unlock_controller_1.requestUnlock);
router.get('/unlock/status/:id', auth_middleware_1.authMiddleware, unlock_controller_1.unlockStatus);
// Approval (no auth — token-based)
router.get('/approve/:token', approval_controller_1.getApprovalPage);
router.post('/approve/:token', approval_controller_1.submitApproval);
// Trusted PIN setup + verification
router.get('/trusted/setup/:token', trustedPin_controller_1.getTrustedSetup);
router.post('/trusted/setup/:token', trustedPin_controller_1.postTrustedSetup);
router.post('/trusted/verify-pin', trustedPin_controller_1.postVerifyTrustedPin);
exports.default = router;

"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getTrustedSetup = getTrustedSetup;
exports.postTrustedSetup = postTrustedSetup;
exports.postVerifyTrustedPin = postVerifyTrustedPin;
const trustedPin_service_1 = require("../services/trustedPin.service");
async function getTrustedSetup(req, res) {
    try {
        const info = await (0, trustedPin_service_1.getSetupInfo)(req.params.token);
        res.json(info);
    }
    catch (err) {
        res.status(400).json({ error: err.message || 'Invalid setup link' });
    }
}
async function postTrustedSetup(req, res) {
    try {
        const { trustedName, pin } = req.body;
        await (0, trustedPin_service_1.setupTrustedPin)(req.params.token, trustedName, pin);
        res.json({ ok: true });
    }
    catch (err) {
        res.status(400).json({ error: err.message || 'Failed to set trusted PIN' });
    }
}
async function postVerifyTrustedPin(req, res) {
    try {
        const { idToken, pin } = req.body;
        const out = await (0, trustedPin_service_1.verifyTrustedPin)(idToken, pin);
        if (!out.ok)
            return res.status(401).json({ ok: false, error: 'Invalid PIN' });
        res.json(out);
    }
    catch (err) {
        res.status(400).json({ error: err.message || 'Failed to verify PIN' });
    }
}

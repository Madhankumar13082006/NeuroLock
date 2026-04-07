"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getApprovalPage = getApprovalPage;
exports.submitApproval = submitApproval;
const approval_service_1 = require("../services/approval.service");
async function getApprovalPage(req, res) {
    try {
        const info = await (0, approval_service_1.getApprovalInfo)(req.params.token);
        res.json({
            appName: info.package_name,
            userEmail: info.user_email,
            token: req.params.token,
        });
    }
    catch (err) {
        res.status(400).json({ error: err.message });
    }
}
async function submitApproval(req, res) {
    try {
        const { decision } = req.body;
        if (!['approve', 'deny'].includes(decision)) {
            return res.status(400).json({ error: 'Invalid decision' });
        }
        const result = await (0, approval_service_1.processApproval)(req.params.token, decision);
        res.json({ status: result.status });
    }
    catch (err) {
        res.status(400).json({ error: err.message });
    }
}

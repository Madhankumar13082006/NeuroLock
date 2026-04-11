"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.authMiddleware = authMiddleware;
const auth_service_1 = require("../services/auth.service");
function authMiddleware(req, res, next) {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Missing authorization header' });
    }
    const token = header.split(' ')[1];
    try {
        const payload = (0, auth_service_1.verifyToken)(token);
        req.userId = payload.userId;
        next();
    }
    catch {
        return res.status(401).json({ error: 'Invalid or expired token' });
    }
}

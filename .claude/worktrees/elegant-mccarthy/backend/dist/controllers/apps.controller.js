"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.addBlockedApp = addBlockedApp;
exports.listBlockedApps = listBlockedApps;
exports.removeBlockedApp = removeBlockedApp;
const zod_1 = require("zod");
const database_1 = require("../config/database");
const appSchema = zod_1.z.object({
    packageName: zod_1.z.string().min(3),
    appName: zod_1.z.string().optional(),
});
async function addBlockedApp(req, res) {
    try {
        const { packageName, appName } = appSchema.parse(req.body);
        const result = await database_1.pool.query(`INSERT INTO blocked_apps (user_id, package_name, app_name)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, package_name) DO NOTHING
       RETURNING *`, [req.userId, packageName, appName ?? packageName]);
        res.status(201).json(result.rows[0] ?? { message: 'Already blocked' });
    }
    catch (err) {
        res.status(400).json({ error: err.message });
    }
}
async function listBlockedApps(req, res) {
    try {
        const result = await database_1.pool.query('SELECT * FROM blocked_apps WHERE user_id = $1', [req.userId]);
        res.json(result.rows);
    }
    catch (err) {
        res.status(500).json({ error: err.message });
    }
}
async function removeBlockedApp(req, res) {
    try {
        await database_1.pool.query('DELETE FROM blocked_apps WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
        res.json({ success: true });
    }
    catch (err) {
        res.status(400).json({ error: err.message });
    }
}

"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.addContact = addContact;
exports.listContacts = listContacts;
exports.deleteContact = deleteContact;
const zod_1 = require("zod");
const database_1 = require("../config/database");
const contactSchema = zod_1.z.object({
    name: zod_1.z.string().min(1).max(100),
    email: zod_1.z.string().email(),
});
async function addContact(req, res) {
    try {
        const { name, email } = contactSchema.parse(req.body);
        const result = await database_1.pool.query('INSERT INTO trusted_contacts (user_id, name, email) VALUES ($1, $2, $3) RETURNING *', [req.userId, name, email]);
        res.status(201).json(result.rows[0]);
    }
    catch (err) {
        res.status(400).json({ error: err.message });
    }
}
async function listContacts(req, res) {
    try {
        const result = await database_1.pool.query('SELECT * FROM trusted_contacts WHERE user_id = $1 ORDER BY created_at DESC', [req.userId]);
        res.json(result.rows);
    }
    catch (err) {
        res.status(500).json({ error: err.message });
    }
}
async function deleteContact(req, res) {
    try {
        await database_1.pool.query('DELETE FROM trusted_contacts WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
        res.json({ success: true });
    }
    catch (err) {
        res.status(400).json({ error: err.message });
    }
}

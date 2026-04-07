"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.register = register;
exports.login = login;
const zod_1 = require("zod");
const auth_service_1 = require("../services/auth.service");
const schema = zod_1.z.object({
    email: zod_1.z.string().email(),
    password: zod_1.z.string().min(6),
});
async function register(req, res) {
    try {
        const { email, password } = schema.parse(req.body);
        const user = await (0, auth_service_1.registerUser)(email, password);
        res.status(201).json({ user });
    }
    catch (err) {
        res.status(400).json({ error: err.message });
    }
}
async function login(req, res) {
    try {
        const { email, password } = schema.parse(req.body);
        const tokens = await (0, auth_service_1.loginUser)(email, password);
        res.json(tokens);
    }
    catch (err) {
        res.status(401).json({ error: err.message });
    }
}

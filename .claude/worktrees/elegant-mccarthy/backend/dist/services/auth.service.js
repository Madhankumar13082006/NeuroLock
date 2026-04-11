"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.registerUser = registerUser;
exports.loginUser = loginUser;
exports.generateTokens = generateTokens;
exports.verifyToken = verifyToken;
const bcrypt_1 = __importDefault(require("bcrypt"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const crypto_1 = require("crypto");
const database_1 = require("../config/database");
const SALT_ROUNDS = 12;
async function registerUser(email, password) {
    const existing = await database_1.pool.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0)
        throw new Error('Email already registered');
    const hash = await bcrypt_1.default.hash(password, SALT_ROUNDS);
    const result = await database_1.pool.query('INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email', [email, hash]);
    return result.rows[0];
}
async function loginUser(email, password) {
    const result = await database_1.pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0)
        throw new Error('Invalid credentials');
    const user = result.rows[0];
    const valid = await bcrypt_1.default.compare(password, user.password_hash);
    if (!valid)
        throw new Error('Invalid credentials');
    return generateTokens(user.id);
}
async function generateTokens(userId) {
    const accessToken = jsonwebtoken_1.default.sign({ userId }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || '15m' });
    const refreshToken = (0, crypto_1.randomBytes)(32).toString('hex');
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await database_1.pool.query('INSERT INTO sessions (user_id, refresh_token, expires_at) VALUES ($1, $2, $3)', [userId, refreshToken, expiresAt]);
    return { accessToken, refreshToken };
}
function verifyToken(token) {
    return jsonwebtoken_1.default.verify(token, process.env.JWT_SECRET);
}

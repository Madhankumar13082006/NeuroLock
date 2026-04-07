"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const supertest_1 = __importDefault(require("supertest"));
const server_1 = __importDefault(require("../server"));
let accessToken;
const testEmail = `unlock_${Date.now()}@test.com`;
beforeAll(async () => {
    await (0, supertest_1.default)(server_1.default).post('/auth/register').send({ email: testEmail, password: 'password123' });
    const res = await (0, supertest_1.default)(server_1.default).post('/auth/login').send({ email: testEmail, password: 'password123' });
    accessToken = res.body.accessToken;
});
describe('Unlock flow', () => {
    it('requires auth', async () => {
        const res = await (0, supertest_1.default)(server_1.default).post('/unlock/request').send({ packageName: 'com.instagram.android' });
        expect(res.status).toBe(401);
    });
    it('creates unlock request', async () => {
        const res = await (0, supertest_1.default)(server_1.default)
            .post('/unlock/request')
            .set('Authorization', `Bearer ${accessToken}`)
            .send({ packageName: 'com.instagram.android' });
        expect([201, 200]).toContain(res.status);
    });
    it('rejects missing packageName', async () => {
        const res = await (0, supertest_1.default)(server_1.default)
            .post('/unlock/request')
            .set('Authorization', `Bearer ${accessToken}`)
            .send({});
        expect(res.status).toBe(400);
    });
});

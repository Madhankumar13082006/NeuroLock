"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const supertest_1 = __importDefault(require("supertest"));
const server_1 = __importDefault(require("../server"));
describe('Approval endpoints', () => {
    it('rejects invalid token', async () => {
        const res = await (0, supertest_1.default)(server_1.default).get('/approve/invalid-token-12345');
        expect(res.status).toBe(400);
        expect(res.body.error).toBeDefined();
    });
    it('rejects invalid decision', async () => {
        const res = await (0, supertest_1.default)(server_1.default)
            .post('/approve/sometoken')
            .send({ decision: 'maybe' });
        expect(res.status).toBe(400);
    });
});

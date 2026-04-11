"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const auth_service_1 = require("../services/auth.service");
const db = __importStar(require("../config/database"));
// Mock the database
jest.mock('../config/database', () => ({
    pool: {
        query: jest.fn(),
    },
}));
// Mock bcrypt
jest.mock('bcrypt', () => ({
    hash: jest.fn().mockResolvedValue('hashedpassword'),
    compare: jest.fn().mockResolvedValue(true),
}));
describe('Auth Service', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });
    it('registers a user', async () => {
        const mockPool = db.pool;
        mockPool.query
            .mockResolvedValueOnce({ rows: [] }) // Check if email exists
            .mockResolvedValueOnce({ rows: [{ id: 'test-id', email: 'test@test.com' }] }); // Insert user
        const result = await (0, auth_service_1.registerUser)('test@test.com', 'password123');
        expect(result.email).toBe('test@test.com');
        expect(mockPool.query).toHaveBeenCalledTimes(2);
    });
    it('throws error on duplicate email', async () => {
        const mockPool = db.pool;
        mockPool.query.mockResolvedValueOnce({ rows: [{ id: 'existing-id' }] }); // Email exists
        await expect((0, auth_service_1.registerUser)('test@test.com', 'password123')).rejects.toThrow('Email already registered');
    });
});

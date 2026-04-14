"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.redis = void 0;
const ioredis_1 = __importDefault(require("ioredis"));
// If REDIS_URL is not provided, do not attempt to connect to localhost by default.
// Local development can run without Redis; queue workers will be disabled.
const redisUrl = process.env.REDIS_URL;
// Export a single `redis` binding so TypeScript always sees the symbol.
// When `REDIS_URL` is unset we export a small stub object with `status: 'disabled'`.
// When set we create a real ioredis client.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
exports.redis = redisUrl
    ? new ioredis_1.default(redisUrl, {
        maxRetriesPerRequest: null,
        enableReadyCheck: false,
        retryStrategy: (time) => {
            if (time > 30000)
                return null;
            return time;
        },
    })
    : {
        status: 'disabled',
        on: (_, __) => { },
    };
if (redisUrl) {
    exports.redis.on('error', (err) => {
        console.warn('Redis connection error (will retry):', err.message);
    });
}

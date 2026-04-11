import Redis from 'ioredis';

// If REDIS_URL is not provided, do not attempt to connect to localhost by default.
// Local development can run without Redis; queue workers will be disabled.
const redisUrl = process.env.REDIS_URL;

// Export a single `redis` binding so TypeScript always sees the symbol.
// When `REDIS_URL` is unset we export a small stub object with `status: 'disabled'`.
// When set we create a real ioredis client.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const redis: any = redisUrl
  ? new Redis(redisUrl, {
      maxRetriesPerRequest: null,
      enableReadyCheck: false,
      retryStrategy: (time: number) => {
        if (time > 30000) return null;
        return time;
      },
    })
  : {
      status: 'disabled',
      on: (_: string, __?: (...args: any[]) => void) => {},
    };

if (redisUrl) {
  redis.on('error', (err: Error) => {
    console.warn('Redis connection error (will retry):', err.message);
  });
}
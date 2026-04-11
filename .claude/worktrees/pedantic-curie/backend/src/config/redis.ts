import Redis from 'ioredis';

export const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
  maxRetriesPerRequest: null,
  enableReadyCheck: false,
  retryStrategy: (time: number) => {
    if (time > 30000) return null;
    return time;
  },
});

redis.on('error', (err: Error) => {
  console.warn('Redis connection error (will retry):', err.message);
});
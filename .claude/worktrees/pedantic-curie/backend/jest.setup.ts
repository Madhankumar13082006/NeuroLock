// Mock BullMQ queue to avoid ESM issues in tests
jest.mock('./src/jobs/queue', () => ({
  unlockQueue: {
    add: jest.fn().mockResolvedValue({ id: 'mock-job-id' }),
    getJob: jest.fn().mockResolvedValue(null),
  },
  fallbackWorker: null,
}));

// Cleanup after tests
afterAll(async () => {
  const { pool } = await import('./src/config/database');
  await pool.end();
});


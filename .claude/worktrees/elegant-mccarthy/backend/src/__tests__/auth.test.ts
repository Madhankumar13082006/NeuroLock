import { registerUser, loginUser } from '../services/auth.service';
import * as db from '../config/database';

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
    const mockPool = db.pool as any;
    mockPool.query
      .mockResolvedValueOnce({ rows: [] }) // Check if email exists
      .mockResolvedValueOnce({ rows: [{ id: 'test-id', email: 'test@test.com' }] }); // Insert user

    const result = await registerUser('test@test.com', 'password123');
    
    expect(result.email).toBe('test@test.com');
    expect(mockPool.query).toHaveBeenCalledTimes(2);
  });

  it('throws error on duplicate email', async () => {
    const mockPool = db.pool as any;
    mockPool.query.mockResolvedValueOnce({ rows: [{ id: 'existing-id' }] }); // Email exists

    await expect(registerUser('test@test.com', 'password123')).rejects.toThrow('Email already registered');
  });
});

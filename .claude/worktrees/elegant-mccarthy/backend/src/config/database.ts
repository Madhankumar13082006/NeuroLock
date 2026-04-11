import { Pool } from 'pg';
import { config } from 'dotenv';
config();

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

pool.on('error', (err: Error) => {
  console.warn('DB pool error (will retry):', err.message);
});
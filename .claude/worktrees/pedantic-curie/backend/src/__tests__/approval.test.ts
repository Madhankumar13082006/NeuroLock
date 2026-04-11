import request from 'supertest';
import app from '../server';

describe('Approval endpoints', () => {
  it('rejects invalid token', async () => {
    const res = await request(app).get('/approve/invalid-token-12345');
    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
  });

  it('rejects invalid decision', async () => {
    const res = await request(app)
      .post('/approve/sometoken')
      .send({ decision: 'maybe' });
    expect(res.status).toBe(400);
  });
});

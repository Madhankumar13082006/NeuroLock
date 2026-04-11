import request from 'supertest';
import app from '../server';

let accessToken: string;
const testEmail = `unlock_${Date.now()}@test.com`;

beforeAll(async () => {
  await request(app).post('/auth/register').send({ email: testEmail, password: 'password123' });
  const res = await request(app).post('/auth/login').send({ email: testEmail, password: 'password123' });
  accessToken = res.body.accessToken;
});

describe('Unlock flow', () => {
  it('requires auth', async () => {
    const res = await request(app).post('/unlock/request').send({ packageName: 'com.instagram.android' });
    expect(res.status).toBe(401);
  });

  it('creates unlock request', async () => {
    const res = await request(app)
      .post('/unlock/request')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ packageName: 'com.instagram.android' });
    expect([201, 200]).toContain(res.status);
  });

  it('rejects missing packageName', async () => {
    const res = await request(app)
      .post('/unlock/request')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({});
    expect(res.status).toBe(400);
  });
});

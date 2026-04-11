#!/usr/bin/env node
/**
 * Create test user using Firebase REST API
 */

const https = require('https');

const WEB_API_KEY = 'AIzaSyCPZtdvrDq3LtvjpYxyf-PLzcefZa9aNWQ';

function createUserWithEmail(email, password) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      email,
      password,
      returnSecureToken: true,
    });

    const options = {
      hostname: 'identitytoolkit.googleapis.com',
      path: `/v1/accounts:signUp?key=${WEB_API_KEY}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length,
      },
    };

    const req = https.request(options, (res) => {
      let responseData = '';
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      res.on('end', () => {
        try {
          const result = JSON.parse(responseData);
          if (res.statusCode === 200) {
            resolve(result);
          } else {
            reject(new Error(result.error?.message || 'Unknown error'));
          }
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function main() {
  try {
    console.log('Creating test user via REST API...');
    const user = await createUserWithEmail('test@example.com', 'password123');
    console.log('✅ User created successfully!');
    console.log('  UID:', user.localId);
    console.log('\nTest credentials:');
    console.log('  Email: test@example.com');
    console.log('  Password: password123');
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

main();

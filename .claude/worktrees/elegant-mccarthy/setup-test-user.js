#!/usr/bin/env node
/**
 * Firebase Admin setup script to create test user
 * Usage: node setup-test-user.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = {
  type: 'service_account',
  project_id: 'impulsecontrol-27cb6',
  private_key_id: 'f6b73d636a4b32f803e1e82cee5f27991d840e5e',
  private_key: '-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC+GH99JJ0O/ybb\nPwF5oEa1SkCE1XD9NW/dgBR5M3RNJ+K6pQmJ5oPmDnvD8Dw9aliJauZ5Ko/VS/iR\n+UTtvBA0lTorMJuqPngbjYDzU9IIqrDSBS+/o3LlmMzE4pAsDwKDh9NpZvn3M6aU\nsnGC83sR/nIZZX7HkxTUHoeOZzHQ1cnVA2YkS9WU/0PLNHPHhMqDYndwqxrNYAmp\nht3/WpCIRPVLpqi1w1uR41Zr+SVeL+yrThH4KVPSz0dKNP3YzuRGVy+YFsc9mB0O\nyGYNORThEJlr/Az1kMt482wRjtr2egZHUGWg84gYyeIv8DSNZnDNnBDQohxpiLKd\nP3FXJ2rVAgMBAAECggEAL37id6uKvGD+3d+/qBpmIEy1kxrbOMC9uvuR4fh7sf1p\ntlWe7QAV64ip3rpq6rNj/K2jeRmrx1DMgfhkgvuultzEJF9oPWCPVN8FnYZPX4/6\nTvcxx3F4tyn226h5+jAj4iYxKdArW1rh35w4JU5dbREEhBjqVMYIeblJCEj7VuBt\nP/nT+b3PXYLul8zbwiS56d3nzDbbvf1RUZBp+PXjkbXoRDOXOS6dIQj7o6KcNSiX\n7qFURGQDNri3p1LHuWZQzyQnltgoPu4jcKGYHupgLOdxVjgzuPeUb5rrC+W5CAhC\nxbIrePOl93mWHR6I3OCQk7c3LQQLY3Vt6CMBB51kTwKBgQDo4GRoqPYKIxKHPxQC\nwQ1n5FasjgW/Abj2Ar1w72LZ2zj24AR8YpB3j8lOERKekdXalcbisj7mI4Zz9lAp\nQcPJD3Adm/+mIr1FNZr3WmupBapBr+Rzx6TzlposE28qoFuNFqYyBOWy+0cPxman\nCHcTjflgU07e7KGua0AzJWQKQwKBgQDQ+KNGT94zRAy84T9FXfpv2KMQrob/do40\nuitfdHMu4n4FcD1tq86x5BEgVfzMu6hjWLIcDi8Jc3g43M1q7KOnBdPuOMknK2fD\nSQvmtpP++B4iDXmF8mPME9surEp2+JVroNMVAQZWVDK6Kx2xlKP8Ph1LH1po71a7\nUOowZz2hBwKBgChkGyZH//y8Ho+UsjzUDSYy5ZGiRH7fppwM15zJ+IQ+0L+JFV4Z\nnmMObmT68xbLxqLWDZvuPJigGsbsNvUg8ftikRihoRLIvblOVeWHKlszn1crUd1/\nCC4ztePlLwfermJnRkYwsUJ88NNcnxtjjXu3yUQazvg9ZMGi2ozEdHiPAoGBAJVW\nisBtxVqXsA6vXhsBjT6u7+G1B+661+egf+yIeOQxomPakVu141HHreGQ8ceR+EV/\nFlHsZPr5FRp12Ssnj9CF3q2o0T/3ygCKTEIFioA06rvlK0ppLZ6jNgkFwXWCMq4m\n0ZJ6GABLzbCzrVXB5usVrLOJ5X+GQ1I8AhCzRxyzAoGAegJKK4v1eR8RKF1rf9sK\nP5VEbf3GW7fQW+DON/XaEdMgXfBatK2FQ4A15zqRipCDZlysvbUkIan67X/lFV+w\nUy045Yv6JbcthUgH0DHJoAKThzq02wHQRr8WQ4V3ozrfk0jwVaqd4oniH8k/HCWP\nApGoWeJAvEkLDCjFI9hU/aM=\n-----END PRIVATE KEY-----\n',
  client_email: 'firebase-adminsdk-fbsvc@impulsecontrol-27cb6.iam.gserviceaccount.com',
  client_id: '100216003724463742377',
  auth_uri: 'https://accounts.google.com/o/oauth2/auth',
  token_uri: 'https://oauth2.googleapis.com/token',
  auth_provider_x509_cert_url: 'https://www.googleapis.com/oauth2/v1/certs',
  client_x509_cert_url: 'https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40impulsecontrol-27cb6.iam.gserviceaccount.com',
};

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'impulsecontrol-27cb6',
});

const db = admin.firestore();
const auth = admin.auth();

async function createTestUser() {
  try {
    console.log('Creating test user...');
    
    // Create user with email/password
    const userRecord = await auth.createUser({
      email: 'test@example.com',
      password: 'password123',
      displayName: 'Test User',
    });
    
    console.log('✅ Auth user created:', userRecord.uid);
    
    // Create user profile in Firestore
    await db.collection('users').doc(userRecord.uid).set({
      email: 'test@example.com',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      uid: userRecord.uid,
      displayName: 'Test User',
    });
    
    console.log('✅ Firestore profile created');
    console.log('\nTest credentials:');
    console.log('  Email: test@example.com');
    console.log('  Password: password123');
    
    process.exit(0);
  } catch (error) {
    if (error.code === 'auth/email-already-exists') {
      console.log('✅ Test user already exists (test@example.com)');
      console.log('\nTest credentials:');
      console.log('  Email: test@example.com');
      console.log('  Password: password123');
    } else {
      console.error('❌ Error:', error.message);
    }
    process.exit(0);
  }
}

createTestUser();

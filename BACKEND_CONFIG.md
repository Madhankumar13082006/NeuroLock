# Backend Configuration - Firebase Cloud Functions

This guide explains how to set up the Firebase backend for the Impulse Control app.

## Current Architecture

**Frontend:** Flutter app with Riverpod for state management  
**Backend:** Firebase (Auth + Firestore)  
**Database:** Firestore collections structured as:

```
users/{uid}/
  ├─ email (string)
  ├─ name (string)
  ├─ createdAt (timestamp)
  ├─ blocks/{packageName}/
  │  ├─ com.youtube:block_shorts (boolean)
  │  ├─ com.youtube:vanced_mode (boolean)
  │  └─ ...more features...
  └─ contacts/{contactId}/
     ├─ displayName (string)
     ├─ phoneNumber (string)
     └─ whatsappUrl (string)

approval_links/{token}/
  ├─ uid (string - creator)
  ├─ blockedFeatures (array)
  ├─ status (string: pending|approved|rejected)
  ├─ pin (string or null)
  ├─ trustedName (string or null)
  ├─ createdAt (timestamp)
  ├─ expiresAt (timestamp)
  └─ unlockedUntil (timestamp or null)
```

## Firestore Security Rules

The app uses the rules defined in `firestore.rules`:

- Users can only access their own documents
- Approval links are readable by anyone (for web unlock page)
- Only authenticated users can create/update blocks and contacts

### Deploying Rules

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Deploy rules
firebase deploy --only firestore:rules
```

## Environment Configuration

### Local Development

- **App Check Provider:** Debug (no verification)
- **Firestore:** Development rules (minimal security)
- **Auth:** Standard Firebase Auth

### Production

- **App Check Provider:** Device Attestation
- **reCAPTCHA:** v3 (continuous verification)
- **Firestore:** Strict security rules
- **Auth:** Device + email verification

## Firebase Console Settings

### Required Configurations

1. **Authentication → Settings → reCAPTCHA Enterprise**
   - [ ] Create/enable reCAPTCHA key
   - [ ] Select reCAPTCHA v2 or v3

2. **Firestore Database → Rules**
   - [ ] Deploy security rules from `firestore.rules`

3. **Authentication → Sign-in methods**
   - [ ] Email/Password: Enabled ✓
   - [ ] Anonymous (optional): For guest testing

### Optional Cloud Functions

For advanced features, you can add Cloud Functions:

```typescript
// functions/src/index.ts - Example

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

// Triggered when user creates account
exports.onUserCreate = functions.firestore
  .document("users/{uid}")
  .onCreate(async (snap, context) => {
    const uid = context.params.uid;
    console.log(`New user created: ${uid}`);
    // Send welcome email, initialize default settings, etc.
  });

// Triggered when approval is submitted
exports.onApprovalSubmit = functions.firestore
  .document("approval_links/{token}")
  .onUpdate(async (change, context) => {
    const token = context.params.token;
    const newData = change.after.data();

    if (newData.status === "approved") {
      // Unlock the app until specified time
      console.log(`Approval granted for: ${token}`);
    }
  });
```

## Testing Backend

### Manual Testing

1. **Register new account:**
   - App: Register screen → create account
   - Firebase Console: Check users appear in Authentication

2. **Save block settings:**
   - App: Home screen → toggle feature
   - Firebase Console: Check `users/{uid}/blocks/` collection

3. **Generate approval link:**
   - App: (trigger unlock flow)
   - Firebase Console: Check `approval_links/` collection

### Monitoring

Check logs in Firebase Console:

- **Authentication** → Sign-in methods → View logs
- **Firestore** → Monitoring → Usage dashboard
- **Cloud Functions** → Logs (if implemented)

## Troubleshooting

### reCAPTCHA CONFIGURATION_NOT_FOUND

**Solution:** Go to Firebase Console → Authentication → Settings → reCAPTCHA Enterprise → Create or enable reCAPTCHA

### Permission Denied in Firestore

**Solution:** Check security rules are deployed. Run: `firebase deploy --only firestore:rules`

### User can't register

**Solution:**

1. Check auth is enabled (Firebase Console → Authentication → Email/Password)
2. Check app's `google-services.json` is correct
3. Check device has internet connection

### Firestore quota exceeded

**Solution:**

1. Enable billing on Firebase project (free tier has daily limits)
2. Check for infinite loops in app code
3. Use Firestore emulator for testing

## Cost Optimization

Current free tier limits (daily):

- **Firestore reads:** 50,000
- **Firestore writes:** 20,000
- **Auth calls:** Unlimited
- **Storage:** 1 GB

For production, estimate:

- Per 1,000 users: $5-20/month
- Per 100,000 API calls: $20-50/month

## Next Steps

1. ✅ Configure reCAPTCHA in Firebase Console
2. ✅ Deploy Firestore security rules
3. ✅ Test registration/login on device
4. ✅ Test block settings storage
5. ⏳ (Future) Implement Cloud Functions for advanced features
6. ⏳ (Future) Setup CI/CD for auto-deployment

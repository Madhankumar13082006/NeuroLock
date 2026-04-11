# ✅ Complete Firebase reCAPTCHA Configuration

## The Problem

Firebase Auth requires reCAPTCHA verification for sign-up/login, but it's not properly configured in your Firebase project.

## The Solution: 5-Step Setup

---

### STEP 1: Create reCAPTCHA Keys on Google

**URL:** https://www.google.com/recaptcha/admin

1. Click **"Create Admin Console Account"** (if first time)
2. Click **"+"** to add a new site
3. Fill in these details:
   ```
   Label: Impulse Control
   reCAPTCHA type: reCAPTCHA v2 (Checkbox - "I'm not a robot")
   Domains:
   - localhost
   - 127.0.0.1
   - example.com (or your web domain)
   ```
4. **Accept terms** and click **Create**
5. Copy:
   - **Site Key:** (You'll see it) - save this somewhere
   - **Secret Key:** (click on it) - **KEEP THIS PRIVATE!**

---

### STEP 2: Link reCAPTCHA to Firebase

**URL:** https://console.firebase.google.com

1. Select project: **impulsecontrol** (impulsecontrol-27cb6)
2. Left menu → **Authentication**
3. Click **Settings** (gear icon at top)
4. Scroll down to: **reCAPTCHA Enterprise settings**
5. Click **"Set up reCAPTCHA v2"**
6. Choose: **"reCAPTCHA v2 (Checkbox)"**
7. Paste your **Site Key** from Step 1
8. **Save** the changes

---

### STEP 3: Enable for Email/Password Auth

While still in Authentication Settings:

1. Scroll to **"Sign-in methods"**
2. Click on **"Email/Password"**
3. Make sure toggle is **ON** (enabled)
4. **Save**

---

### STEP 4: Deploy Firestore Security Rules

Run these commands from your computer:

```bash
# Install Firebase tools (one time)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Go to project directory
cd K:\projects\impulse-control

# Deploy the rules
firebase deploy --only firestore:rules
```

---

### STEP 5: Test the App

1. **Restart the Flutter app** on your device (hot reload won't work)
2. Tap **"Create Account"**
3. Fill in:
   - Name: `Test User`
   - Email: `test@example.com`
   - Password: `password123`
   - Confirm: `password123`
4. Tap **"Create Account"**

### Expected Result ✅

- "Account created! Please sign in." message appears
- Redirected to Login screen
- Can login with same credentials
- Taken to Home screen

---

## If Still Getting Error

| Error                      | Fix                                                                          |
| -------------------------- | ---------------------------------------------------------------------------- |
| "reCAPTCHA not configured" | Verify reCAPTCHA is set in Firebase Console (Step 2)                         |
| "unexpected end of stream" | Network issue. Try: (1) Different email, (2) Check internet, (3) Restart app |
| "Something went wrong"     | Check Firebase Console logs for errors                                       |
| "Email already in use"     | Use a different email address you haven't registered yet                     |

---

## What Each Component Does

| Component            | Purpose                                          |
| -------------------- | ------------------------------------------------ |
| **Google reCAPTCHA** | Verifies users are human (prevents bots)         |
| **Firebase Auth**    | Handles user registration & login                |
| **Firestore**        | Stores user profiles & app settings              |
| **Security Rules**   | Protects data (only users access their own data) |

---

## ⚠️ Important Notes

- **Never share your Secret Key** - it's like a password
- **Site Key is public** - it's safe to share
- **Firestore Rules** - must be deployed for data to be accessible
- **Free tier limitation** - reCAPTCHA may have daily limits on free tier
- **If production** - enable reCAPTCHA v3 (advanced) for better user experience

---

## Quick Verification Checklist

- [ ] Created reCAPTCHA v2 key on google.com/recaptcha/admin
- [ ] Copied Site Key and Secret Key
- [ ] Went to Firebase Console → Authentication → Settings
- [ ] Pasted Site Key in reCAPTCHA settings
- [ ] Enabled Email/Password sign-in method
- [ ] Ran `firebase deploy --only firestore:rules`
- [ ] Restarted Flutter app
- [ ] Tried registering new account

Once all checked, registration should work! ✅

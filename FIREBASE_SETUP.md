# Firebase Backend Setup Guide

## ❌ Problem: reCAPTCHA CONFIGURATION_NOT_FOUND Error

This error occurs when Firebase Authentication is trying to enforce reCAPTCHA, but it's not properly configured.

---

## ✅ Solution: Configure Firebase Console

### Step 1: Go to Firebase Console

1. Open: https://console.firebase.google.com
2. Select your project: **impulsecontrol** (impulsecontrol-27cb6)

### Step 2: Configure reCAPTCHA

**Path:** Authentication → Settings → reCAPTCHA Enterprise settings

#### Option A: Simple Fix (Recommended for Testing)

1. Click **"Non-reCAPTCHA enforcement"** (if available)
2. Or click the 3-dot menu → **"Disable reCAPTCHA"**
3. This allows app registration without strict reCAPTCHA verification

#### Option B: Setup reCAPTCHA v2 (Production)

1. Click **"Create reCAPTCHA key"**
2. Select: **reCAPTCHA v2 (Android)**
3. Add your package name: `com.impulsecontrol`
4. Save the key

### Step 3: Deploy Firestore Rules

**Path:** Firestore Database → Rules

1. Copy all content from `firestore.rules` in this project
2. Paste into Firebase Console Rules editor
3. Click **"Publish"**

### Step 4: Enable Anonymous Authentication (Optional for Testing)

**Path:** Authentication → Sign-in methods

1. Enable **"Anonymous"** sign-in
2. This allows testing without strict verification

---

## 🔧 Alternative: Use Firebase Emulator (Local Testing)

For complete offline testing without Firebase Console setup:

```bash
# Install Firebase Emulator Suite
npm install -g firebase-tools

# Start emulator
firebase emulators:start

# In your Flutter app, connect to emulator
# (Already configured in lib/firebase_options.dart)
```

---

## 📋 Current Firebase Configuration (In Your App)

**Project:** impulsecontrol-27cb6  
**Region:** us-central1  
**API Key:** AIzaSyCPZtdvrDq3LtvjpYxyf-PLzcefZa9aNWQ

These are correctly configured in `lib/firebase_options.dart`

---

## 🚀 Quick Test After Setup

1. **Register**: `test@example.com` / `password123`
2. **Login**: Use same credentials
3. **Create Block**: Toggle a feature on home screen
4. **Check Firestore**: Verify data saved in Firebase Console

---

## ⚠️ If Still Getting Error

1. **Check Billing**: Enable billing on Firebase project (free tier has limits)
2. **Check Authentication Status**:
   - Go to Authentication → Users tab
   - Should see newly created users
3. **Check Firestore**:
   - Go to Firestore Database
   - Should see `users/` collection with your data
4. **Check Logs**:
   - Run: `firebase functions:log` (if using functions)

---

## 📝 What These Rules Allow

| Action               | Anonymous | Authenticated | Admin |
| -------------------- | --------- | ------------- | ----- |
| Create account       | ✅        | ✅            | ✅    |
| Read own user doc    | ❌        | ✅            | ✅    |
| Write own user doc   | ❌        | ✅            | ✅    |
| Read approval links  | ✅        | ✅            | ✅    |
| Create approval link | ❌        | ✅            | ✅    |

---

## 🔐 Production Checklist (For Later)

- [ ] Enable reCAPTCHA v3 (advanced verification)
- [ ] Set up App Check with real device provider
- [ ] Restrict API keys to specific APIs
- [ ] Enable Firestore backups
- [ ] Setup Cloud Armor for DDoS protection
- [ ] Enable Admin audit logs

// reCAPTCHA Configuration Guide

This file explains how to set up reCAPTCHA for proper Firebase authentication.

## Step 1: Get reCAPTCHA Keys from Google

1. Go to: https://www.google.com/recaptcha/admin
2. Click "+" to create new site
3. Fill in:
   - Name: "Impulse Control"
   - reCAPTCHA type: Choose "reCAPTCHA v2" → "I'm not a robot" Checkbox
   - Domains:
     - impulsecontrol.page (or your web domain)
     - Add Android app package: com.impulsecontrol
4. Copy:
   - Site Key: (save this)
   - Secret Key: (save this - keep private!)

## Step 2: Configure Firebase Console

1. Go to: https://console.firebase.google.com
2. Select project: "impulsecontrol-27cb6"
3. Navigate to: Authentication → Settings
4. Scroll down to: "reCAPTCHA Enterprise settings"
5. Click "Create reCAPTCHA key" or "Associate existing key"
6. Select the reCAPTCHA v2 key you created above
7. Enable it for "Email/Password" authentication

## Step 3: Add reCAPTCHA to Dart App

The app now includes reCAPTCHA support through FirebaseAuth automatically.
Firebase's Android SDK will automatically include the reCAPTCHA token with auth requests.

## Step 4: Verify Setup

1. Register a new account on the app
2. If successful, check Firebase Console → Authentication → Users
3. New user should appear in the list
4. Check Firestore → users collection for user document

## Step 5: Deploy Firestore Rules

Run from project root:

```bash
npm install -g firebase-tools
firebase login
firebase deploy --only firestore:rules
```

## Quick Test

After setup:

1. Open app
2. Go to Register
3. Enter:
   - Name: Test User
   - Email: test@example.com
   - Password: password123
4. Click Create Account
5. Should show "Account created! Please sign in."
6. Try to login with same credentials
7. Should navigate to home screen

If registration fails with "reCAPTCHA" error:

- Check if reCAPTCHA is properly linked in Firebase Console
- Ensure project has Blaze (paid) plan enabled (free tier has limitations)
- Try using a different email domain

## Troubleshooting

| Error                      | Solution                                                         |
| -------------------------- | ---------------------------------------------------------------- |
| "CONFIGURATION_NOT_FOUND"  | Enable reCAPTCHA in Firebase Console                             |
| "unexpected end of stream" | Network issue - check internet connection or try different email |
| "Permission denied"        | Check Firestore rules are deployed                               |
| "Email already in use"     | Use different email address                                      |

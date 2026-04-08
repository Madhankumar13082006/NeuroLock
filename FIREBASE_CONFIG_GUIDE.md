// Firebase Console Configuration for Development
//
// To fix the reCAPTCHA CONFIGURATION_NOT_FOUND error, follow these steps:
//
// 1. Go to Firebase Console: https://console.firebase.google.com
// 2. Select project: "impulsecontrol"
// 3. Navigate to: Authentication → Settings
// 4. Under "reCAPTCHA Enterprise settings":
// - Click "Create reCAPTCHA key" or use existing one
// - For development, you can:
// Option A: Use reCAPTCHA v2 (simpler setup)
// Option B: Enable "Non-reCAPTCHA enforcement" for testing
//
// 5. Go to: Firestore Database → Rules
// - Copy and paste the content of firestore.rules
// - Click "Publish"
//
// 6. (Optional) In Firebase Console → Settings → Service Accounts:
// - If you want to use Firebase Admin SDK for backend
//
// 7. Run this command to deploy rules locally:
// firebase deploy --only firestore:rules
//
// For testing without strict reCAPTCHA:
// - Use the debug App Check provider (already configured in main.dart)
// - Firebase will use lenient verification in debug builds
//
// If you still get reCAPTCHA errors:
// 1. Try alternate email domain (e.g., test@example.com)
// 2. Check if project billing is enabled
// 3. Use Firebase Emulator for local testing
//
// ============================================
// QUICK FIX: Disable reCAPTCHA temporarily
// ============================================
// 1. Firebase Console → Authentication → Settings
// 2. Find "reCAPTCHA Enterprise settings"
// 3. Click the three dots menu → "Disable" or "Test"
// 4. This allows unauthenticated testing

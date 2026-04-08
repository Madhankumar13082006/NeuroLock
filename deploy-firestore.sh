#!/bin/bash
# Deploy Firestore security rules to Firebase
# Run this from the project root: bash deploy-firestore.sh

echo "📋 Deploying Firestore Security Rules..."
echo ""
echo "Prerequisites:"
echo "1. Install Firebase CLI: npm install -g firebase-tools"
echo "2. Login to Firebase: firebase login"
echo "3. Select project: firebase use impulsecontrol-27cb6"
echo ""
echo "Then run:"
echo "  firebase deploy --only firestore:rules"
echo ""
echo "Or deploy everything:"
echo "  firebase deploy"

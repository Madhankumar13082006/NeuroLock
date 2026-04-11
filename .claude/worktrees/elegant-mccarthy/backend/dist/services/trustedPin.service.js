"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getSetupInfo = getSetupInfo;
exports.setupTrustedPin = setupTrustedPin;
exports.verifyTrustedPin = verifyTrustedPin;
const bcrypt_1 = __importDefault(require("bcrypt"));
const firebaseAdmin_1 = require("../config/firebaseAdmin");
const LOCK_DOC = 'main';
const PIN_SALT_ROUNDS = 12;
async function getSetupInfo(token) {
    const ref = firebaseAdmin_1.firestore.collection('approval_links').doc(token);
    const snap = await ref.get();
    if (!snap.exists)
        throw new Error('Invalid setup link');
    const data = snap.data();
    if (data.status !== 'pending') {
        throw new Error('This setup link is already used');
    }
    const expiresAt = data.expiresAt;
    if (expiresAt && expiresAt.toDate().getTime() < Date.now()) {
        throw new Error('Setup link expired');
    }
    const uid = String(data.uid ?? '');
    const user = await firebaseAdmin_1.firebaseAuth.getUser(uid);
    return {
        uid,
        userName: user.displayName || user.email || 'Nokkon user',
        blockedFeatures: data.blockedFeatures ?? [],
    };
}
async function setupTrustedPin(token, trustedName, pin) {
    if (!/^\d{4}$/.test(pin))
        throw new Error('PIN must be 4 digits');
    const info = await getSetupInfo(token);
    const lockRef = firebaseAdmin_1.firestore
        .collection('users')
        .doc(info.uid)
        .collection('lock_state')
        .doc(LOCK_DOC);
    const linkRef = firebaseAdmin_1.firestore.collection('approval_links').doc(token);
    await firebaseAdmin_1.firestore.runTransaction(async (tx) => {
        const lockSnap = await tx.get(lockRef);
        const linkSnap = await tx.get(linkRef);
        const linkData = linkSnap.data();
        if (!linkData || linkData.status !== 'pending') {
            throw new Error('Setup link is no longer active');
        }
        const now = new Date();
        const current = lockSnap.data()?.currentPIN ?? null;
        const nextHash = await bcrypt_1.default.hash(pin, PIN_SALT_ROUNDS);
        const previousExpiry = new Date(now.getTime() + 60 * 60 * 1000);
        tx.set(lockRef, {
            isLocked: true,
            isPinSet: true,
            currentPIN: nextHash,
            previousPIN: current,
            previousPINExpiry: current ? previousExpiry : null,
            unlockExpiry: null,
            delayTimer: null,
            trustedName,
            updatedAt: now,
        }, { merge: true });
        tx.update(linkRef, {
            status: 'used',
            trustedName,
            approvedAt: now,
            pin: null,
            usedAt: now,
        });
    });
}
async function verifyTrustedPin(idToken, pin) {
    if (!/^\d{4}$/.test(pin))
        throw new Error('PIN must be 4 digits');
    const decoded = await firebaseAdmin_1.firebaseAuth.verifyIdToken(idToken);
    const uid = decoded.uid;
    const lockRef = firebaseAdmin_1.firestore
        .collection('users')
        .doc(uid)
        .collection('lock_state')
        .doc(LOCK_DOC);
    const snap = await lockRef.get();
    if (!snap.exists)
        throw new Error('Lock setup not found');
    const data = snap.data() || {};
    const now = Date.now();
    const currentHash = data.currentPIN ?? null;
    const previousHash = data.previousPIN ?? null;
    const previousExpiry = data.previousPINExpiry?.toDate().getTime() ?? 0;
    let valid = false;
    if (currentHash)
        valid = await bcrypt_1.default.compare(pin, currentHash);
    if (!valid && previousHash && now <= previousExpiry) {
        valid = await bcrypt_1.default.compare(pin, previousHash);
    }
    if (!valid)
        return { ok: false };
    const unlockUntil = new Date(now + 60 * 60 * 1000);
    await lockRef.set({
        unlockExpiry: unlockUntil,
        isLocked: true,
        isPinSet: true,
        updatedAt: new Date(),
    }, { merge: true });
    return { ok: true, unlockUntilMs: unlockUntil.getTime() };
}

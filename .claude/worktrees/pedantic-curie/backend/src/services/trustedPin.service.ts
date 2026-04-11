import bcrypt from 'bcrypt';
import { firestore, firebaseAuth } from '../config/firebaseAdmin';

const LOCK_DOC = 'main';
const PIN_SALT_ROUNDS = 12;

type LockDoc = {
  isLocked?: boolean;
  currentPIN?: string | null;
  previousPIN?: string | null;
  previousPINExpiry?: FirebaseFirestore.Timestamp | null;
  unlockExpiry?: FirebaseFirestore.Timestamp | null;
  delayTimer?: FirebaseFirestore.Timestamp | null;
  blockedFeatures?: string[];
};

export async function getSetupInfo(token: string) {
  const ref = firestore.collection('approval_links').doc(token);
  const snap = await ref.get();
  if (!snap.exists) throw new Error('Invalid setup link');
  const data = snap.data() as Record<string, unknown>;
  if ((data.status as string) !== 'pending') {
    throw new Error('This setup link is already used');
  }
  const expiresAt = data.expiresAt as FirebaseFirestore.Timestamp | undefined;
  if (expiresAt && expiresAt.toDate().getTime() < Date.now()) {
    throw new Error('Setup link expired');
  }

  const uid = String(data.uid ?? '');
  const user = await firebaseAuth.getUser(uid);
  return {
    uid,
    userName: user.displayName || user.email || 'Nokkon user',
    blockedFeatures: (data.blockedFeatures as string[] | undefined) ?? [],
  };
}

export async function setupTrustedPin(
  token: string,
  trustedName: string,
  pin: string
) {
  if (!/^\d{4}$/.test(pin)) throw new Error('PIN must be 4 digits');
  const info = await getSetupInfo(token);

  const lockRef = firestore
    .collection('users')
    .doc(info.uid)
    .collection('lock_state')
    .doc(LOCK_DOC);
  const linkRef = firestore.collection('approval_links').doc(token);

  await firestore.runTransaction(async (tx) => {
    const lockSnap = await tx.get(lockRef);
    const linkSnap = await tx.get(linkRef);
    const linkData = linkSnap.data() as Record<string, unknown> | undefined;
    if (!linkData || (linkData.status as string) !== 'pending') {
      throw new Error('Setup link is no longer active');
    }

    const now = new Date();
    const current = (lockSnap.data() as LockDoc | undefined)?.currentPIN ?? null;
    const nextHash = await bcrypt.hash(pin, PIN_SALT_ROUNDS);
    const previousExpiry = new Date(now.getTime() + 60 * 60 * 1000);

    tx.set(
      lockRef,
      {
        isLocked: true,
        isPinSet: true,
        currentPIN: nextHash,
        previousPIN: current,
        previousPINExpiry: current ? previousExpiry : null,
        unlockExpiry: null,
        delayTimer: null,
        trustedName,
        updatedAt: now,
      },
      { merge: true }
    );

    tx.update(linkRef, {
      status: 'used',
      trustedName,
      approvedAt: now,
      pin: null,
      usedAt: now,
    });
  });
}

export async function verifyTrustedPin(idToken: string, pin: string) {
  if (!/^\d{4}$/.test(pin)) throw new Error('PIN must be 4 digits');
  const decoded = await firebaseAuth.verifyIdToken(idToken);
  const uid = decoded.uid;

  const lockRef = firestore
    .collection('users')
    .doc(uid)
    .collection('lock_state')
    .doc(LOCK_DOC);
  const snap = await lockRef.get();
  if (!snap.exists) throw new Error('Lock setup not found');
  const data = (snap.data() as LockDoc) || {};

  const now = Date.now();
  const currentHash = data.currentPIN ?? null;
  const previousHash = data.previousPIN ?? null;
  const previousExpiry = data.previousPINExpiry?.toDate().getTime() ?? 0;

  let valid = false;
  if (currentHash) valid = await bcrypt.compare(pin, currentHash);
  if (!valid && previousHash && now <= previousExpiry) {
    valid = await bcrypt.compare(pin, previousHash);
  }
  if (!valid) return { ok: false };

  const unlockUntil = new Date(now + 60 * 60 * 1000);
  await lockRef.set(
    {
      unlockExpiry: unlockUntil,
      isLocked: true,
      isPinSet: true,
      updatedAt: new Date(),
    },
    { merge: true }
  );

  return { ok: true, unlockUntilMs: unlockUntil.getTime() };
}


import express from "express";
import admin from "firebase-admin";
import cors from "cors";
import dotenv from "dotenv";

dotenv.config();

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(
    JSON.parse(process.env.FIREBASE_ADMIN_SDK || "{}")
  ),
  databaseURL: process.env.FIREBASE_DATABASE_URL,
});

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// ── HEALTH CHECK ────────────────────────────────
app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "Nokkon Backend" });
});

app.get("/", (req, res) => {
  res.json({ message: "Nokkon Backend Running", version: "1.0.0" });
});

// ── LINK APPROVAL ────────────────────────────────
/**
 * POST /api/approve
 * Trusted person approves unlock link and sets PIN
 * Body: { token, pin, trustedName }
 */
app.post("/api/approve", async (req, res) => {
  try {
    const { token, pin, trustedName } = req.body;

    if (!token || !pin || pin.length !== 4 || !trustedName) {
      return res.status(400).json({ error: "Invalid input" });
    }

    const db = admin.firestore();
    const linkDoc = await db.collection("approval_links").doc(token).get();

    if (!linkDoc.exists) {
      return res.status(404).json({ error: "Link not found or expired" });
    }

    const data = linkDoc.data();
    if (data?.status !== "pending") {
      return res.status(400).json({ error: "Link already used" });
    }

    const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

    await db.collection("approval_links").doc(token).update({
      status: "approved",
      pin,
      trustedName,
      approvedAt: new Date(),
      expiresAt,
    });

    res.json({ success: true, message: "PIN set successfully" });
  } catch (error) {
    console.error("Approval error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// ── VERIFY PIN ────────────────────────────────
/**
 * POST /api/verify-pin
 * Verify PIN for unlock
 * Body: { token, pin, uid }
 */
app.post("/api/verify-pin", async (req, res) => {
  try {
    const { token, pin, uid } = req.body;

    if (!token || !pin || !uid) {
      return res.status(400).json({ error: "Missing parameters" });
    }

    const db = admin.firestore();
    const linkDoc = await db.collection("approval_links").doc(token).get();

    if (!linkDoc.exists) {
      return res.status(404).json({ error: "Invalid link" });
    }

    const data = linkDoc.data();

    if (data?.uid !== uid) {
      return res.status(403).json({ error: "Unauthorized" });
    }

    if (data?.status !== "approved") {
      return res.status(400).json({ error: "Link not approved" });
    }

    if (new Date(data?.expiresAt) < new Date()) {
      return res.status(400).json({ error: "Link expired" });
    }

    if (data?.pin !== pin) {
      return res.status(401).json({ error: "Incorrect PIN" });
    }

    res.json({ success: true, message: "PIN verified" });
  } catch (error) {
    console.error("PIN verification error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// ── GET LOCK STATUS ────────────────────────────────
/**
 * GET /api/locks/:uid
 * Get all locks for a user
 */
app.get("/api/locks/:uid", async (req, res) => {
  try {
    const { uid } = req.params;
    const db = admin.firestore();

    const locks = await db
      .collection("locks")
      .where("uid", "==", uid)
      .get();

    const data = locks.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.json({ success: true, locks: data });
  } catch (error) {
    console.error("Get locks error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// ── GENERATE LINK ────────────────────────────────
/**
 * POST /api/generate-link
 * Generate new approval link
 * Body: { uid, blockedFeatures }
 */
app.post("/api/generate-link", async (req, res) => {
  try {
    const { uid, blockedFeatures } = req.body;

    if (!uid || !blockedFeatures || !Array.isArray(blockedFeatures)) {
      return res.status(400).json({ error: "Invalid input" });
    }

    const db = admin.firestore();
    const token = Math.random().toString(36).substring(2, 15);
    const expiresAt = new Date(Date.now() + 48 * 60 * 60 * 1000); // 48 hours

    await db.collection("approval_links").doc(token).set({
      uid,
      blockedFeatures,
      status: "pending",
      pin: null,
      trustedName: null,
      createdAt: new Date(),
      expiresAt,
    });

    // Generate link (in production, use dynamic links or custom domain)
    const link = `${
      process.env.APP_URL || "http://localhost:3000"
    }/approve?token=${token}`;

    res.json({ success: true, link });
  } catch (error) {
    console.error("Generate link error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// ── SERVER STARTUP ────────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`✅ Nokkon Backend running on port ${PORT}`);
});
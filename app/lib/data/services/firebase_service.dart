import 'dart:math';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

class PinVerifyResult {
  final bool ok;
  final int? unlockUntilMs;
  final String? message;

  const PinVerifyResult({
    required this.ok,
    this.unlockUntilMs,
    this.message,
  });
}

class LockStateDoc {
  final bool isLocked;
  final bool isPinSet;
  final DateTime? unlockExpiry;
  final DateTime? delayTimer;
  final String? currentPinHash;

  const LockStateDoc({
    required this.isLocked,
    required this.isPinSet,
    this.unlockExpiry,
    this.delayTimer,
    this.currentPinHash,
  });

  factory LockStateDoc.fromMap(Map<String, dynamic> data) {
    final hash = data['currentPIN'];
    // Only treat PIN as configured when the bcrypt hash exists. A bare
    // `isPinSet: true` without `currentPIN` came from an older app bug and
    // would hide invite links and block PIN verification.
    final hasBcryptPin = hash is String && hash.isNotEmpty;
    return LockStateDoc(
      isLocked: (data['isLocked'] as bool?) ?? true,
      isPinSet: hasBcryptPin,
      unlockExpiry: (data['unlockExpiry'] as Timestamp?)?.toDate(),
      delayTimer: (data['delayTimer'] as Timestamp?)?.toDate(),
      currentPinHash: hasBcryptPin ? hash : null,
    );
  }
}

class FirebaseService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String get uid => _auth.currentUser!.uid;
  Stream<User?> get authChanges => _auth.authStateChanges();

  // ── AUTH ──────────────────────────────────────────────────
  Future<void> register(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);

    // Save user profile to Firestore with proper types
    await _db.collection('users').doc(cred.user!.uid).set({
      'email': email,
      'name': name,
      'uid': cred.user!.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _auth.signOut(); // force login after register
  }

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logout() => _auth.signOut();

  Future<String?> getUserName() async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['name'] as String?;
  }

  // ── APP BLOCK SETTINGS ────────────────────────────────────
  Future<void> saveFeatureBlock(
      String pkg, String featureKey, bool value) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('blocks')
        .doc(pkg)
        .set({featureKey: value}, SetOptions(merge: true));
  }

  Future<void> saveFeatureUsageLimitMinutes(
    String pkg,
    String featureKey,
    int minutes,
  ) async {
    await _db.collection('users').doc(uid).collection('blocks').doc(pkg).set(
      {'${featureKey}_limit_minutes': minutes},
      SetOptions(merge: true),
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchBlocks(String pkg) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('blocks')
        .doc(pkg)
        .snapshots();
  }

  Future<Map<String, dynamic>> getBlocks(String pkg) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('blocks')
        .doc(pkg)
        .get();
    return doc.data() ?? {};
  }

  // ── LINK GENERATION ───────────────────────────────────────
  Future<String> generateApprovalLink(
      {required String packageName,
      required List<String> blockedFeatures}) async {
    final token = _generateToken();
    final expiresAt = DateTime.now().add(const Duration(hours: 24));

    await _db.collection('approval_links').doc(token).set({
      'uid': uid,
      'packageName': packageName,
      'blockedFeatures': blockedFeatures,
      'status': 'pending',
      'pin': null,
      'trustedName': null,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'unlockedUntil': null,
    });

    // Build invite URL safely to avoid accidental double slashes.
    return Uri.parse('${AppConstants.inviteLinkBase}/')
        .resolve('invite/$token')
        .toString();
  }

  String _generateToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(24, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// True after a trusted contact has stored a PIN (hash) for this account.
  Future<bool> hasTrustedPinSetup() async {
    final state = await getLockState();
    return state.isPinSet;
  }

  Stream<LockStateDoc> watchLockState() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('lock_state')
        .doc('main')
        .snapshots()
        .map((snap) {
      final data = snap.data() ?? {};
      return LockStateDoc.fromMap(data);
    });
  }

  Future<LockStateDoc> getLockState() async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('lock_state')
        .doc('main')
        .get();
    return LockStateDoc.fromMap(doc.data() ?? {});
  }

  /// Checks the PIN with the trusted API but does **not** open an unlock window
  /// or write [unlockExpiry]. Use before clearing the PIN for a new invite link.
  Future<PinVerifyResult> verifyPinIdentityOnly(String pin) async {
    final idToken = await _auth.currentUser?.getIdToken();
    if (idToken == null) {
      return const PinVerifyResult(
        ok: false,
        message: 'Not signed in. Open NeuroLock and log in again.',
      );
    }
    final apiRoot = AppConstants.baseUrlNormalized;
    if (!apiRoot.startsWith('http')) {
      return const PinVerifyResult(
        ok: false,
        message: 'Invalid API URL in app settings (must start with http).',
      );
    }
    final uri = Uri.parse('$apiRoot/trusted/verify-pin');
    try {
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 25));

      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>?;
      } catch (_) {
        body = null;
      }

      if (res.statusCode != 200) {
        final err = body?['error']?.toString() ??
            body?['message']?.toString() ??
            'Server returned ${res.statusCode}';
        return PinVerifyResult(
          ok: false,
          message: res.statusCode == 401
              ? 'Wrong PIN, or PIN not saved yet. Ask your friend to finish the invite link.'
              : err,
        );
      }

      final ok = body?['ok'] == true;
      if (!ok) {
        return PinVerifyResult(
          ok: false,
          message: body?['error']?.toString() ?? 'Wrong PIN',
        );
      }
      return const PinVerifyResult(ok: true);
    } catch (e) {
      return PinVerifyResult(
        ok: false,
        message:
            'Cannot reach API at $apiRoot - same Wi-Fi as your PC? Fix IP in '
            'lib/core/constants.dart and use cleartext HTTP only on LAN.\n($e)',
      );
    }
  }

  /// Local-first identity check:
  /// - if we have a cached trusted PIN hash, verify offline (no internet)
  /// - otherwise fall back to the trusted API identity check.
  Future<PinVerifyResult> verifyPinIdentityLocalFirst(String pin) async {
    final okOffline = await _verifyOfflinePinBcrypt(pin);
    if (okOffline) return const PinVerifyResult(ok: true);
    return verifyPinIdentityOnly(pin);
  }

  Future<PinVerifyResult> verifyPin(String pin) async {
    // Local-first: if a trusted PIN hash is cached, verify offline without network.
    final localOk = await _verifyOfflinePinBcrypt(pin);
    if (localOk) {
      final until = DateTime.now().add(const Duration(hours: 1));
      return PinVerifyResult(
          ok: true, unlockUntilMs: until.millisecondsSinceEpoch);
    }

    final idToken = await _auth.currentUser?.getIdToken();
    if (idToken == null) {
      return const PinVerifyResult(
        ok: false,
        message: 'Not signed in. Open NeuroLock and log in again.',
      );
    }
    final apiRoot = AppConstants.baseUrlNormalized;
    if (!apiRoot.startsWith('http')) {
      return const PinVerifyResult(
        ok: false,
        message: 'Invalid API URL in app settings (must start with http).',
      );
    }
    final uri = Uri.parse('$apiRoot/trusted/verify-pin');
    try {
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 25));

      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>?;
      } catch (_) {
        body = null;
      }

      if (res.statusCode != 200) {
        final err = body?['error']?.toString() ??
            body?['message']?.toString() ??
            'Server returned ${res.statusCode}';
        return PinVerifyResult(
          ok: false,
          message: res.statusCode == 401
              ? 'Wrong PIN, or PIN not saved yet. Ask your friend to finish the invite link.'
              : err,
        );
      }

      final unlockUntil = body?['unlockUntilMs'] as num?;
      final ok = body?['ok'] == true;
      if (ok && unlockUntil != null) {
        await _db
            .collection('users')
            .doc(uid)
            .collection('lock_state')
            .doc('main')
            .set({
          'unlockExpiry':
              Timestamp.fromMillisecondsSinceEpoch(unlockUntil.toInt()),
          'isLocked': true,
          'isPinSet': true,
        }, SetOptions(merge: true));
        // Cache offline PIN so future unlocks can be local-first.
        // (Hash-only; no raw PIN stored.)
        await _cacheOfflinePinLegacySha(pin);
        return PinVerifyResult(ok: true, unlockUntilMs: unlockUntil.toInt());
      }
      return PinVerifyResult(
        ok: ok,
        unlockUntilMs: unlockUntil?.toInt(),
        message: ok ? null : (body?['error']?.toString() ?? 'Could not unlock'),
      );
    } catch (e) {
      // Network failed; try offline (bcrypt hash from Firebase cache, then legacy sha cache).
      final offlineOk = await _verifyOfflinePinBcrypt(pin) ||
          await _verifyOfflinePinLegacySha(pin);
      if (offlineOk) {
        final until = DateTime.now().add(const Duration(hours: 1));
        return PinVerifyResult(
            ok: true, unlockUntilMs: until.millisecondsSinceEpoch);
      }
      return PinVerifyResult(
        ok: false,
        message:
            'Cannot reach API at $apiRoot. If you previously unlocked once online, '
            'offline emergency unlock should work. ($e)',
      );
    }
  }

  // ── OFFLINE PIN CACHE (bcrypt from Firebase + legacy sha fallback) ───────────
  static const _offlinePrefsKeyBcrypt = 'offline_pin_bcrypt_v1';
  static const _offlinePrefsKeySalt = 'offline_pin_salt_v1';
  static const _offlinePrefsKeyHash = 'offline_pin_hash_v1';

  Future<void> cacheTrustedPinHashForOffline(String? bcryptHash) async {
    final prefs = await SharedPreferences.getInstance();
    if (bcryptHash == null || bcryptHash.isEmpty) {
      await prefs.remove(_offlinePrefsKeyBcrypt);
      return;
    }
    await prefs.setString(_offlinePrefsKeyBcrypt, bcryptHash);
  }

  Future<void> clearOfflinePinCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlinePrefsKeyBcrypt);
    await prefs.remove(_offlinePrefsKeySalt);
    await prefs.remove(_offlinePrefsKeyHash);
  }

  Future<bool> _verifyOfflinePinBcrypt(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hash = prefs.getString(_offlinePrefsKeyBcrypt);
      if (hash == null || hash.isEmpty) return false;
      return BCrypt.checkpw(pin, hash);
    } catch (_) {
      return false;
    }
  }

  // Legacy offline hash: kept only for devices that already cached it.
  Future<void> _cacheOfflinePinLegacySha(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = prefs.getString(_offlinePrefsKeySalt) ?? _newSalt();
    if (prefs.getString(_offlinePrefsKeySalt) == null) {
      await prefs.setString(_offlinePrefsKeySalt, salt);
    }
    final hash = sha256.convert(utf8.encode('$salt:$pin')).toString();
    await prefs.setString(_offlinePrefsKeyHash, hash);
  }

  Future<bool> _verifyOfflinePinLegacySha(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salt = prefs.getString(_offlinePrefsKeySalt);
      if (salt == null || salt.isEmpty) return false;
      final expected = prefs.getString(_offlinePrefsKeyHash);
      if (expected == null || expected.isEmpty) return false;
      final actual = sha256.convert(utf8.encode('$salt:$pin')).toString();
      return actual == expected;
    } catch (_) {
      return false;
    }
  }

  String _newSalt() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(20, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<bool> isUnlocked() async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('lock_state')
        .doc('main')
        .get();
    final until = (doc.data()?['unlockExpiry'] as Timestamp?)?.toDate();
    return until != null && until.isAfter(DateTime.now());
  }

  Future<DateTime?> getUnlockExpiry() async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('lock_state')
        .doc('main')
        .get();
    return (doc.data()?['unlockExpiry'] as Timestamp?)?.toDate();
  }

  // ── UNLOCK STATE ──────────────────────────────────────────
  /// Temporary unlock window (e.g. after 20-minute wait). Must not set
  /// `isPinSet` or the app will think a trusted PIN already exists and
  /// will stop offering invite links.
  Future<void> saveLocalUnlock(DateTime until) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('lock_state')
        .doc('main')
        .set({
      'unlockExpiry': Timestamp.fromDate(until),
      'isLocked': true,
    }, SetOptions(merge: true));
  }

  /// Clears temporary unlock so Firestore matches the device after a session ends.
  Future<void> clearUnlockExpiry() async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('lock_state')
        .doc('main')
        .set(
      {'unlockExpiry': FieldValue.delete()},
      SetOptions(merge: true),
    );
  }

  /// Clears the trusted PIN after a PIN-based unlock window expires, so the
  /// user must generate a new invite link and ask their friend to set a new PIN.
  Future<void> clearCurrentPin() async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('lock_state')
        .doc('main')
        .set({
      'currentPIN': FieldValue.delete(),
      'previousPIN': FieldValue.delete(),
      'previousPINExpiry': FieldValue.delete(),
      'isPinSet': false,
    }, SetOptions(merge: true));
  }

  Future<bool> isSelfUnlocked() async {
    final doc = await _db.collection('users').doc(uid).get();
    final until = (doc.data()?['selfUnlockUntil'] as Timestamp?)?.toDate();
    return until != null && until.isAfter(DateTime.now());
  }

  // ── CONTACTS ────────────────────────────────────────────────
  Future<void> addContact(String name, String phone) async {
    await _db.collection('users').doc(uid).collection('contacts').add({
      'name': name,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> watchContacts() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteContact(String contactId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .doc(contactId)
        .delete();
  }
}

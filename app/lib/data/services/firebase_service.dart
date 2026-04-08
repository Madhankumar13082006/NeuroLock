import 'dart:math';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';

class LockStateDoc {
  final bool isLocked;
  final bool isPinSet;
  final DateTime? unlockExpiry;
  final DateTime? delayTimer;

  const LockStateDoc({
    required this.isLocked,
    required this.isPinSet,
    this.unlockExpiry,
    this.delayTimer,
  });

  factory LockStateDoc.fromMap(Map<String, dynamic> data) {
    return LockStateDoc(
      isLocked: (data['isLocked'] as bool?) ?? true,
      isPinSet: (data['isPinSet'] as bool?) ?? false,
      unlockExpiry: (data['unlockExpiry'] as Timestamp?)?.toDate(),
      delayTimer: (data['delayTimer'] as Timestamp?)?.toDate(),
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
    final expiresAt = DateTime.now().add(const Duration(hours: 48));

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

    // Hosted approval page (backend serves static /approve/approve.html)
    return '${AppConstants.baseUrl}/approve/approve.html?token=$token';
  }

  String _generateToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(24, (_) => chars[rng.nextInt(chars.length)]).join();
  }

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

  Future<bool> verifyPin(String pin) async {
    final idToken = await _auth.currentUser?.getIdToken();
    if (idToken == null) return false;
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/trusted/verify-pin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken, 'pin': pin}),
    );
    if (res.statusCode != 200) return false;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final unlockUntil = body['unlockUntilMs'] as num?;
    if (unlockUntil != null) {
      await _db
          .collection('users')
          .doc(uid)
          .collection('lock_state')
          .doc('main')
          .set({
        'unlockExpiry': Timestamp.fromMillisecondsSinceEpoch(unlockUntil.toInt()),
        'isLocked': true,
        'isPinSet': true,
      }, SetOptions(merge: true));
    }
    return body['ok'] == true;
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
  Future<void> saveLocalUnlock(DateTime until) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('lock_state')
        .doc('main')
        .set({
      'unlockExpiry': Timestamp.fromDate(until),
      'isLocked': true,
      'isPinSet': true,
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

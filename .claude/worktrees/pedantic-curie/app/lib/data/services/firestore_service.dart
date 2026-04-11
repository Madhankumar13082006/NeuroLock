import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // ── App Block Settings ─────────────────────────────────
  Future<Map<String, dynamic>> getAppSettings(String packageName) async {
    final doc = await _db
        .collection('users')
        .doc(_uid)
        .collection('app_settings')
        .doc(packageName)
        .get();
    return doc.data() ?? {};
  }

  Future<void> saveAppSetting(
      String packageName, String featureKey, bool value) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('app_settings')
        .doc(packageName)
        .set({featureKey: value}, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> watchAppSettings(String packageName) {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('app_settings')
        .doc(packageName)
        .snapshots();
  }

  // ── Trusted Contacts ───────────────────────────────────
  Future<void> addContact(String name, String phone) async {
    await _db.collection('users').doc(_uid).collection('contacts').add({
      'name': name,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> watchContacts() {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('contacts')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> deleteContact(String contactId) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('contacts')
        .doc(contactId)
        .delete();
  }

  // ── Unlock Requests ────────────────────────────────────
  Future<String> createUnlockRequest(String appName) async {
    final ref = await _db
        .collection('users')
        .doc(_uid)
        .collection('unlock_requests')
        .add({
      'appName': appName,
      'status': 'WAITING',
      'requestedAt': FieldValue.serverTimestamp(),
      'expiresAt':
          Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 20))),
    });
    return ref.id;
  }

  Stream<DocumentSnapshot> watchUnlockRequest(String requestId) {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('unlock_requests')
        .doc(requestId)
        .snapshots();
  }

  Future<void> approveUnlock(String requestId) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('unlock_requests')
        .doc(requestId)
        .update({
      'status': 'APPROVED',
      'approvedAt': FieldValue.serverTimestamp(),
      'unlockedUntil':
          Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 30))),
    });
  }

  // ── Usage Stats (mocked for now) ───────────────────────
  Map<String, double> getMockUsage(String packageName) {
    if (packageName == 'com.google.android.youtube') {
      return {
        'Shorts': 88.6,
        'Search': 3.7,
        'Pip': 1.2,
        'Comments': 0.9,
        'Other': 5.6,
      };
    }
    if (packageName == 'com.instagram.android') {
      return {
        'Reels': 72.4,
        'Explore': 14.2,
        'Stories': 8.1,
        'Other': 5.3,
      };
    }
    return {'Usage': 100.0};
  }
}

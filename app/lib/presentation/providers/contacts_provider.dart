import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/firestore_service.dart';

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

final contactsStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  return ref.watch(firestoreServiceProvider).watchContacts();
});

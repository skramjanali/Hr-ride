
import 'package:cloud_firestore/cloud_firestore.dart';

class RideLifecycleService {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  static const transitions = <String, Set<String>>{
    'requested': {'assigned','cancelled'},
    'assigned': {'arriving','cancelled'},
    'arriving': {'started','cancelled'},
    'started': {'completed'},
    'completed': {},
    'cancelled': {},
  };

  Future<bool> transition(String rideId, String nextStatus) async {
    final ref = db.collection('rides').doc(rideId);
    return db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final data = snap.data()!;
      final current = data['status'] as String? ?? 'requested';
      if (!(transitions[current] ?? {}).contains(nextStatus)) return false;
      tx.update(ref, {
        'status': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Stream<DocumentSnapshot<Map<String,dynamic>>> stream(String rideId) =>
      db.collection('rides').doc(rideId).snapshots();
}

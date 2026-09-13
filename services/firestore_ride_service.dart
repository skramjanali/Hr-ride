
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreRideService {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  Future<void> setDriverOnline({
    required String driverId, required String name,
    required double lat, required double lng,
    String vehicle='Maruti Ertiga',
  }) async => db.collection('drivers').doc(driverId).set({
    'driverId':driverId,'name':name,'vehicle':vehicle,'online':true,
    'lat':lat,'lng':lng,'updatedAt':FieldValue.serverTimestamp(),
  }, SetOptions(merge:true));

  Future<void> setDriverOffline(String driverId) async =>
      db.collection('drivers').doc(driverId).set(
        {'online':false,'updatedAt':FieldValue.serverTimestamp()},
        SetOptions(merge:true));

  Future<void> updateDriverLocation(String driverId,double lat,double lng) async =>
      db.collection('drivers').doc(driverId).set({
        'lat':lat,'lng':lng,'online':true,'updatedAt':FieldValue.serverTimestamp(),
      },SetOptions(merge:true));

  Future<String> createRide({
    required String customerId, required String pickup, required String destination,
    required double pickupLat, required double pickupLng,
    required double fare, required double distanceKm,
  }) async {
    final ref=db.collection('rides').doc();
    await ref.set({
      'rideId':ref.id,'customerId':customerId,'pickup':pickup,'destination':destination,
      'pickupLat':pickupLat,'pickupLng':pickupLng,'fare':fare,'distanceKm':distanceKm,
      'status':'requested','driverId':null,'driverName':null,'driverVehicle':null,
      'createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<DocumentSnapshot<Map<String,dynamic>>> rideStream(String id) =>
      db.collection('rides').doc(id).snapshots();

  Stream<QuerySnapshot<Map<String,dynamic>>> requestedRides() =>
      db.collection('rides').where('status',isEqualTo:'requested').snapshots();

  Future<bool> acceptRide(String rideId,String driverId,String name,String vehicle) async {
    final ref=db.collection('rides').doc(rideId);
    return db.runTransaction((tx) async {
      final snap=await tx.get(ref);
      if(!snap.exists) return false;
      final data=snap.data()!;
      if(data['status']!='requested' || data['driverId']!=null) return false;
      tx.update(ref,{
        'driverId':driverId,'driverName':name,'driverVehicle':vehicle,
        'status':'assigned','updatedAt':FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Future<void> updateRideStatus(String id,String status) async =>
      db.collection('rides').doc(id).update(
        {'status':status,'updatedAt':FieldValue.serverTimestamp()});

  Future<void> cancelRide(String id) => updateRideStatus(id,'cancelled');
}

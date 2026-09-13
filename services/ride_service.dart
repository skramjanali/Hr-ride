import '../models/ride.dart';

class RideService {
  // Local demo service. Replace these methods with Firebase/REST calls
  // when production backend credentials are configured.
  final List<Ride> _rides = [];

  Future<Ride> requestRide({
    required String pickup,
    required String destination,
    required double distanceKm,
    required double fare,
  }) async {
    final ride = Ride(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pickup: pickup,
      destination: destination,
      distanceKm: distanceKm,
      fare: fare,
    );
    _rides.add(ride);
    return ride;
  }

  Future<List<Ride>> history() async => List.unmodifiable(_rides);

  Future<void> updateStatus(String id, RideStatus status) async {
    final ride = _rides.where((r) => r.id == id).firstOrNull;
    if (ride != null) ride.status = status;
  }
}

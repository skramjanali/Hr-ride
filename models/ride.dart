enum RideStatus { requested, assigned, arriving, started, completed, cancelled }

class Ride {
  final String id;
  final String pickup;
  final String destination;
  final String vehicle;
  final double distanceKm;
  final double fare;
  RideStatus status;

  Ride({
    required this.id,
    required this.pickup,
    required this.destination,
    this.vehicle = 'Maruti Ertiga',
    this.distanceKm = 0,
    this.fare = 0,
    this.status = RideStatus.requested,
  });
}

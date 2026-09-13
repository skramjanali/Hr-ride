
enum VehicleFareType { ac, nonAc }

class FareQuote {
  final VehicleFareType type;
  final double distanceKm;
  final double ratePerKm;
  final double baseFare;
  final double estimatedFare;

  const FareQuote({
    required this.type,
    required this.distanceKm,
    required this.ratePerKm,
    required this.baseFare,
    required this.estimatedFare,
  });
}

class FareService {
  static const double acRate = 17;
  static const double nonAcRate = 15;

  FareQuote quote({
    required double distanceKm,
    required VehicleFareType type,
  }) {
    final rate = type == VehicleFareType.ac ? acRate : nonAcRate;
    final fare = distanceKm * rate;
    return FareQuote(
      type: type,
      distanceKm: distanceKm,
      ratePerKm: rate,
      baseFare: 0,
      estimatedFare: fare,
    );
  }
}

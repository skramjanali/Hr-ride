
class NotificationService {
  // Scaffold only. Connect Firebase Cloud Messaging / APNs in production.
  Future<void> initialize() async {}
  Future<void> notifyRideStatus(String status) async {}
}

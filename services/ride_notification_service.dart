
import 'package:firebase_messaging/firebase_messaging.dart';

class RideNotificationService {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  Future<String?> initialize() async {
    await messaging.requestPermission(alert:true,badge:true,sound:true);
    return messaging.getToken();
  }

  Future<void> subscribeRide(String rideId) =>
      messaging.subscribeToTopic('ride_$rideId');

  Future<void> unsubscribeRide(String rideId) =>
      messaging.unsubscribeFromTopic('ride_$rideId');
}

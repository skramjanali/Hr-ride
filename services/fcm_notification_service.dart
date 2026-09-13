
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<String?> initialize() async {
    await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
      provisional: false,
    );
    return _messaging.getToken();
  }

  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get openedMessages => FirebaseMessaging.onMessageOpenedApp;

  Future<void> subscribeToRideTopic(String rideId) =>
      _messaging.subscribeToTopic('ride_$rideId');

  Future<void> unsubscribeFromRideTopic(String rideId) =>
      _messaging.unsubscribeFromTopic('ride_$rideId');
}


class ProductionConfig {
  static const appName = 'HR RIDE';
  static const supportPhone = '9002266005';
  static const serviceArea = 'West Bengal';
  static const vehicle = 'Maruti Ertiga';

  // Supply these through --dart-define in a real release build.
  static const mapsApiKey = String.fromEnvironment('MAPS_API_KEY');
  static const backendUrl = String.fromEnvironment('BACKEND_URL');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const paymentKey = String.fromEnvironment('PAYMENT_KEY');
}

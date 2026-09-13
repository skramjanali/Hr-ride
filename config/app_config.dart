class AppConfig {
  static const appName = 'HR RIDE';
  static const supportPhone = '9002266005';
  static const serviceArea = 'West Bengal';
  static const defaultVehicle = 'Maruti Ertiga';

  // Set these only in a secure production environment.
  static const mapsApiKey = String.fromEnvironment('MAPS_API_KEY');
  static const backendBaseUrl = String.fromEnvironment('BACKEND_URL');
}

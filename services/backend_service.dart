import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendService {
  final String baseUrl;
  BackendService(this.baseUrl);

  Future<Map<String, dynamic>> health() async {
    final r = await http.get(Uri.parse('$baseUrl/health'));
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Backend unavailable');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createRide({
    required String pickup,
    required String destination,
    required double distanceKm,
    required double fare,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/rides'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'pickup': pickup,
        'destination': destination,
        'distanceKm': distanceKm,
        'fare': fare,
        'vehicle': 'Maruti Ertiga',
      }),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Ride request failed');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}

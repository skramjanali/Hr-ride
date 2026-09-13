
import 'dart:convert';
import 'package:http/http.dart' as http;

class RideStatusService {
  final String baseUrl;
  RideStatusService(this.baseUrl);

  Future<Map<String,dynamic>> getRide(String rideId) async {
    final r=await http.get(Uri.parse('$baseUrl/rides/$rideId'));
    if(r.statusCode!=200) throw Exception('Ride not found');
    return jsonDecode(r.body) as Map<String,dynamic>;
  }

  Future<Map<String,dynamic>> setStatus(String rideId,String status) async {
    final r=await http.patch(Uri.parse('$baseUrl/rides/$rideId/status'),
      headers:{'Content-Type':'application/json'}, body:jsonEncode({'status':status}));
    if(r.statusCode!=200) throw Exception('Status update failed');
    return jsonDecode(r.body) as Map<String,dynamic>;
  }
}

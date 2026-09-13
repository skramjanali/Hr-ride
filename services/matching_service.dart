
import 'dart:convert';
import 'package:http/http.dart' as http;

class DriverMatch {
  final String driverId;
  final String name;
  final String vehicle;
  final double lat;
  final double lng;
  final double distanceKm;

  DriverMatch({
    required this.driverId,
    required this.name,
    required this.vehicle,
    required this.lat,
    required this.lng,
    required this.distanceKm,
  });

  factory DriverMatch.fromJson(Map<String,dynamic> j) => DriverMatch(
    driverId: j['driverId'] as String,
    name: (j['name'] ?? 'HR RIDE Driver') as String,
    vehicle: (j['vehicle'] ?? 'Maruti Ertiga') as String,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
  );
}

class MatchingService {
  final String baseUrl;
  MatchingService(this.baseUrl);

  Future<List<DriverMatch>> nearbyDrivers(double lat, double lng) async {
    final r = await http.get(Uri.parse('$baseUrl/drivers/nearby?lat=$lat&lng=$lng'));
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('Nearby driver search failed');
    final list = jsonDecode(r.body) as List;
    return list.map((e)=>DriverMatch.fromJson(e)).toList();
  }

  Future<Map<String,dynamic>> setDriverOnline({
    required String driverId, required double lat, required double lng, String name='HR RIDE Driver'
  }) async {
    final r = await http.post(Uri.parse('$baseUrl/drivers/online'),
      headers:{'Content-Type':'application/json'},
      body:jsonEncode({'driverId':driverId,'name':name,'lat':lat,'lng':lng,'vehicle':'Maruti Ertiga'}));
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('Driver online failed');
    return jsonDecode(r.body) as Map<String,dynamic>;
  }

  Future<void> updateDriverLocation(String driverId,double lat,double lng) async {
    final r = await http.patch(Uri.parse('$baseUrl/drivers/$driverId/location'),
      headers:{'Content-Type':'application/json'}, body:jsonEncode({'lat':lat,'lng':lng}));
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('Driver location update failed');
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';

class MapTrackingScreen extends StatefulWidget {
  const MapTrackingScreen({super.key});
  @override State<MapTrackingScreen> createState() => _MapTrackingScreenState();
}

class _MapTrackingScreenState extends State<MapTrackingScreen> {
  final _location = LocationService();
  GoogleMapController? _map;
  StreamSubscription? _sub;
  LatLng? _me;
  bool loading = true;
  String message = 'Getting your location…';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final pos = await _location.currentPosition();
    if (!mounted) return;
    if (pos == null) {
      setState(() { loading = false; message = 'Location permission/service is off.'; });
      return;
    }
    final point = LatLng(pos.latitude, pos.longitude);
    setState(() { _me = point; loading = false; message = 'GPS active'; });
    _map?.animateCamera(CameraUpdate.newLatLngZoom(point, 16));
    _sub = _location.watch().listen((p) {
      final point = LatLng(p.latitude, p.longitude);
      if (!mounted) return;
      setState(() => _me = point);
      _map?.animateCamera(CameraUpdate.newLatLng(point));
    });
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('HR RIDE • Live GPS')),
    body: Stack(children: [
      GoogleMap(
        initialCameraPosition: const CameraPosition(target: LatLng(22.5726, 88.3639), zoom: 11),
        myLocationEnabled: _me != null,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: false,
        onMapCreated: (c) { _map = c; if (_me != null) c.animateCamera(CameraUpdate.newLatLngZoom(_me!, 16)); },
        markers: _me == null ? {} : {Marker(markerId: const MarkerId('customer'), position: _me!, infoWindow: const InfoWindow(title: 'Your location'))},
      ),
      Positioned(
        left: 16, right: 16, top: 16,
        child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          Icon(loading ? Icons.gps_not_fixed : Icons.gps_fixed, color: loading ? Colors.orange : Colors.green),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ]))),
      ),
    ]),
  );
}

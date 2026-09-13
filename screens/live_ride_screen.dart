
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LiveRideScreen extends StatefulWidget {
  final String baseUrl;
  final String rideId;
  const LiveRideScreen({super.key, required this.baseUrl, required this.rideId});
  @override State<LiveRideScreen> createState()=>_LiveRideScreenState();
}

class _LiveRideScreenState extends State<LiveRideScreen> {
  Timer? timer;
  GoogleMapController? map;
  Map<String,dynamic>? ride;
  String message='Connecting to live ride…';

  @override void initState(){super.initState(); _poll(); timer=Timer.periodic(const Duration(seconds:3),(_)=>_poll());}
  Future<void> _poll() async {
    try {
      final r=await http.get(Uri.parse('${widget.baseUrl}/rides/${widget.rideId}'));
      if(r.statusCode!=200) throw Exception();
      final data=jsonDecode(r.body) as Map<String,dynamic>;
      if(!mounted)return;
      setState(()=>ride=data);
      final d=data['driver'];
      if(d is Map && d['lat']!=null && d['lng']!=null){
        final p=LatLng((d['lat'] as num).toDouble(),(d['lng'] as num).toDouble());
        map?.animateCamera(CameraUpdate.newLatLng(p));
      }
      setState(()=>message='Live • ${data['status']}');
    } catch (_) {
      if(mounted)setState(()=>message='Backend not connected');
    }
  }

  @override void dispose(){timer?.cancel();super.dispose();}

  @override Widget build(BuildContext context){
    final d=ride?['driver'];
    final markers=<Marker>{};
    if(d is Map && d['lat']!=null && d['lng']!=null){
      markers.add(Marker(markerId:const MarkerId('driver'),
        position:LatLng((d['lat'] as num).toDouble(),(d['lng'] as num).toDouble()),
        infoWindow:InfoWindow(title:d['name']??'Driver')));
    }
    final pLat=ride?['pickupLat'], pLng=ride?['pickupLng'];
    if(pLat is num && pLng is num) markers.add(Marker(markerId:const MarkerId('pickup'),
      position:LatLng(pLat.toDouble(),pLng.toDouble()), infoWindow:const InfoWindow(title:'Pickup')));
    return Scaffold(
      appBar:AppBar(title:const Text('HR RIDE • Live Ride')),
      body:Stack(children:[
        GoogleMap(initialCameraPosition:const CameraPosition(target:LatLng(22.5726,88.3639),zoom:11),
          onMapCreated:(c)=>map=c, markers:markers, myLocationButtonEnabled:true),
        Positioned(left:12,right:12,top:12,child:Card(child:Padding(
          padding:const EdgeInsets.all(14), child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(message,style:const TextStyle(fontWeight:FontWeight.bold)),
            const SizedBox(height:6),
            Text('Status: ${ride?['status'] ?? '—'}'),
            if(d is Map) Text('Driver: ${d['name']} • ${d['vehicle']}'),
          ]))),
      ]),
    );
  }
}

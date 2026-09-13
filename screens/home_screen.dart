
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firestore_ride_service.dart';
import '../services/ride_lifecycle_service.dart';
import '../services/ride_notification_service.dart';
import 'live_ride_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  final pickup=TextEditingController(), destination=TextEditingController();
  final db=FirestoreRideService(), life=RideLifecycleService(), notifications=RideNotificationService();
  double distance=200; bool booking=false;
  String? rideId; StreamSubscription? rideSub; StreamSubscription<RemoteMessage>? msgSub;
  Map<String,dynamic>? ride;

  Future<Position?> pos() async {
    if(!await Geolocator.isLocationServiceEnabled())return null;
    var p=await Geolocator.checkPermission();
    if(p==LocationPermission.denied)p=await Geolocator.requestPermission();
    if(p==LocationPermission.denied||p==LocationPermission.deniedForever)return null;
    return Geolocator.getCurrentPosition();
  }
  Future<void> book() async {
    if(pickup.text.trim().isEmpty||destination.text.trim().isEmpty){_msg('Pickup and destination দিন');return;}
    setState(()=>booking=true);
    try{
      final p=await pos(); if(p==null)throw Exception('GPS permission/service is off');
      final uid=FirebaseAuth.instance.currentUser?.uid??'demo_customer';
      final id=await db.createRide(customerId:uid,pickup:pickup.text.trim(),destination:destination.text.trim(),
        pickupLat:p.latitude,pickupLng:p.longitude,fare:17*distance,distanceKm:distance);
      rideId=id;
      await notifications.initialize();
      await notifications.subscribeRide(id);
      msgSub=FirebaseMessaging.onMessage.listen((m){if(m.notification!=null)_msg(m.notification!.title??'HR RIDE update');});
      rideSub=db.rideStream(id).listen((s){if(mounted&&s.exists)setState(()=>ride=s.data());});
    }catch(e){_msg('$e');}
    finally{if(mounted)setState(()=>booking=false);}
  }
  Future<void> cancel() async {if(rideId!=null)await life.transition(rideId!,'cancelled');}
  void _msg(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}

  @override void dispose(){rideSub?.cancel();msgSub?.cancel();pickup.dispose();destination.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final status=ride?['status'] as String?;
    final active=status!=null&&!['completed','cancelled'].contains(status);
    return Scaffold(appBar:AppBar(title:const Text('HR RIDE',style:TextStyle(fontWeight:FontWeight.w800))),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(
          gradient:const LinearGradient(colors:[Color(0xFF0A3D91),Color(0xFF0B5DEB)]),
          borderRadius:BorderRadius.circular(24)),child:const Row(children:[
          Icon(Icons.local_taxi,color:Colors.white,size:46),SizedBox(width:14),
          Text('HR RIDE',style:TextStyle(color:Colors.white,fontSize:26,fontWeight:FontWeight.w900))])),
        const SizedBox(height:16),
        TextField(controller:pickup,decoration:const InputDecoration(labelText:'Pickup',prefixIcon:Icon(Icons.my_location),border:OutlineInputBorder())),
        const SizedBox(height:10),
        TextField(controller:destination,decoration:const InputDecoration(labelText:'Destination',prefixIcon:Icon(Icons.location_on),border:OutlineInputBorder())),
        const SizedBox(height:14),
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
          const Align(alignment:Alignment.centerLeft,child:Text('Maruti Ertiga • 6+1 seats',style:TextStyle(fontWeight:FontWeight.bold))),
          Row(children:[const Text('Distance'),Expanded(child:Slider(value:distance,min:1,max:200,divisions:199,label:'${distance.round()} km',
            onChanged:active?null:(v)=>setState(()=>distance=v))),Text('${distance.round()} km')]),
          Align(alignment:Alignment.centerLeft,child:Text('AC ₹17/km • Estimated ₹${(17*distance).toStringAsFixed(0)}')),
          const Align(alignment:Alignment.centerLeft,child:Text('Minimum 200 km • Toll tax & parking separate',style:TextStyle(color:Colors.grey))),
        ]))),
        const SizedBox(height:12),
        if(ride!=null) Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Ride Status: ${(status??'').toUpperCase()}',style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
          const SizedBox(height:8),
          if(status=='requested')const Row(children:[CircularProgressIndicator(strokeWidth:2),SizedBox(width:10),Text('Finding available driver…')]),
          if(ride!['driverId']!=null) ...[
            ListTile(contentPadding:EdgeInsets.zero,leading:const CircleAvatar(child:Icon(Icons.person)),
              title:Text(ride!['driverName']??'HR RIDE Driver'),
              subtitle:Text(ride!['driverVehicle']??'Maruti Ertiga'),
              trailing:const Icon(Icons.verified)],
          ],
          if(rideId!=null&&status!='cancelled') OutlinedButton.icon(
            onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>LiveRideScreen(baseUrl:'http://10.0.2.2:8080',rideId:rideId!))),
            icon:const Icon(Icons.map),label:const Text('LIVE TRACKING')),
          if(active)TextButton.icon(onPressed:cancel,icon:const Icon(Icons.cancel_outlined),label:const Text('Cancel Ride')),
          if(status=='completed')const Text('Ride completed successfully. Thank you for riding with HR RIDE!'),
        ]))),
        const SizedBox(height:12),
        FilledButton.icon(onPressed:(booking||active)?null:book,icon:const Icon(Icons.local_taxi),
          label:Text(booking?'BOOKING…':'BOOK RIDE'),style:FilledButton.styleFrom(padding:const EdgeInsets.symmetric(vertical:16))),
        const SizedBox(height:12),
        const ListTile(leading:Icon(Icons.support_agent),title:Text('24/7 Support'),subtitle:Text('9002266005 • West Bengal')),
      ]));
  }
}

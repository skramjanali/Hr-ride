
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firestore_ride_service.dart';
import '../services/ride_lifecycle_service.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});
  @override State<DriverScreen> createState()=>_DriverScreenState();
}
class _DriverScreenState extends State<DriverScreen> {
  final db=FirestoreRideService();
  final life=RideLifecycleService();
  StreamSubscription<Position>? gps;
  StreamSubscription<QuerySnapshot<Map<String,dynamic>>>? requests;
  bool online=false;
  final name='HR RIDE Driver';
  final vehicle='Maruti Ertiga';

  Future<Position?> pos() async {
    if(!await Geolocator.isLocationServiceEnabled()) return null;
    var p=await Geolocator.checkPermission();
    if(p==LocationPermission.denied)p=await Geolocator.requestPermission();
    if(p==LocationPermission.denied||p==LocationPermission.deniedForever)return null;
    return Geolocator.getCurrentPosition();
  }

  Future<void> toggle(bool v) async {
    final uid=FirebaseAuth.instance.currentUser?.uid;
    if(uid==null)return;
    if(v){
      final p=await pos();
      if(p==null){_msg('GPS permission/service is required');return;}
      await db.setDriverOnline(driverId:uid,name:name,lat:p.latitude,lng:p.longitude);
      gps=Geolocator.getPositionStream(locationSettings:const LocationSettings(
        accuracy:LocationAccuracy.high,distanceFilter:10)).listen(
          (p)=>db.updateDriverLocation(uid,p.latitude,p.longitude));
      setState(()=>online=true);
    }else{
      await db.setDriverOffline(uid);
      await gps?.cancel();
      setState(()=>online=false);
    }
  }

  Future<void> accept(String id) async {
    final uid=FirebaseAuth.instance.currentUser?.uid;
    if(uid==null)return;
    final ok=await db.acceptRide(id,uid,name,vehicle);
    _msg(ok?'Ride accepted':'Ride already taken');
  }
  Future<void> next(String id,String current) async {
    final next = {'assigned':'arriving','arriving':'started','started':'completed'}[current];
    if(next==null)return;
    final ok=await life.transition(id,next);
    _msg(ok?'Ride status: $next':'Status change failed');
  }
  void _msg(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}

  @override void dispose(){gps?.cancel();requests?.cancel();super.dispose();}

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('HR RIDE • Driver')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Driver Dashboard',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
        const SizedBox(height:6),const Text('Maruti Ertiga • West Bengal'),
        SwitchListTile(contentPadding:EdgeInsets.zero,
          title:Text(online?'You are Online':'You are Offline'),
          subtitle:Text(online?'Receiving requests + sharing GPS':'Go online to receive rides'),
          value:online,onChanged:toggle),
      ]))),
      if(online) StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream:db.requestedRides(),
        builder:(c,s){
          final docs=s.data?.docs??[];
          if(docs.isEmpty)return const Card(child:Padding(
            padding:EdgeInsets.all(18),child:Text('No new ride requests')));
          return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Padding(padding:EdgeInsets.symmetric(vertical:12),
              child:Text('New Requests',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
            ...docs.map((d){final x=d.data();return Card(child:ListTile(
              title:Text('${x['pickup']??'Pickup'} → ${x['destination']??'Destination'}'),
              subtitle:Text('₹${x['fare']??0} • ${x['distanceKm']??0} km'),
              trailing:FilledButton(onPressed:()=>accept(d.id),child:const Text('ACCEPT')),
            ));}),
          ]);
        }),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream:FirebaseFirestore.instance.collection('rides')
          .where('driverId',isEqualTo:FirebaseAuth.instance.currentUser?.uid)
          .where('status',whereIn:['assigned','arriving','started']).snapshots(),
        builder:(c,s){
          final docs=s.data?.docs??[];
          return Column(children:docs.map((d){
            final x=d.data(); final st=x['status'] as String? ?? 'assigned';
            final label={'assigned':'START ARRIVING','arriving':'START RIDE','started':'COMPLETE RIDE'}[st]!;
            return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Active Ride',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
              const SizedBox(height:6),
              Text('${x['pickup']} → ${x['destination']}'),
              Text('Status: ${st.toUpperCase()}'),
              const SizedBox(height:8),
              SizedBox(width:double.infinity,child:FilledButton(
                onPressed:()=>next(d.id,st),child:Text(label))),
            ])));
          }).toList());
        }),
      const Card(child:ListTile(leading:Icon(Icons.gps_fixed),title:Text('Live GPS'),
        subtitle:Text('Updates automatically while online'))),
    ]),
  );
}


import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('HR RIDE • Admin')),
    body:StreamBuilder<QuerySnapshot>(
      stream:FirebaseFirestore.instance.collection('drivers').snapshots(),
      builder:(c,s){
        final docs=s.data?.docs??[];
        final online=docs.where((d){final x=d.data() as Map<String,dynamic>;return x['online']==true;}).length;
        return ListView(padding:const EdgeInsets.all(16),children:[
          const Text('Live Operations',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
          const SizedBox(height:12),
          _stat('Registered Drivers','${docs.length}',Icons.drive_eta),
          _stat('Online Drivers','$online',Icons.gps_fixed),
          StreamBuilder<QuerySnapshot>(stream:FirebaseFirestore.instance.collection('rides').snapshots(),builder:(c,r){
            final rides=r.data?.docs??[];
            final active=rides.where((d){final x=d.data() as Map<String,dynamic>;return !['completed','cancelled'].contains(x['status']);}).length;
            return Column(children:[_stat('Total Rides','${rides.length}',Icons.route),_stat('Active Rides','$active',Icons.local_taxi)]);
          }),
        ]);
      },
    ),
  );
  Widget _stat(String t,String v,IconData i)=>Card(child:ListTile(leading:Icon(i,size:32),title:Text(t),trailing:Text(v,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold))));
}


import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home_screen.dart';
import 'screens/firebase_otp_login_screen.dart';
import 'screens/driver_screen.dart';
import 'screens/admin_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const HrRideApp());
}

class HrRideApp extends StatelessWidget {
  const HrRideApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'HR RIDE',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5DEB)),
      scaffoldBackgroundColor: const Color(0xFFF6F8FC),
    ),
    home: FirebaseAuth.instance.currentUser == null ? const FirebaseOtpLoginScreen() : const RoleLauncher(),
  );
}

class RoleLauncher extends StatelessWidget {
  const RoleLauncher({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/hr_ride_logo.png', width: 160, height: 160),
              const SizedBox(height: 18),
              const Text('HR RIDE',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Your Ride, Our Priority'),
              const SizedBox(height: 4),
              const Text('v15 • Firebase + Live Operations',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 26),
              _button(context, 'Customer App', const HomeScreen()),
              _button(context, 'Driver App', const DriverScreen()),
              _button(context, 'Admin Panel', const AdminScreen()),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _button(BuildContext c, String text, Widget page) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: FilledButton(
      onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: Text(text),
    ),
  );
}

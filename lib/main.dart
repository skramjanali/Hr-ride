import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const HRRideApp());
}

class HRRideApp extends StatelessWidget {
  const HRRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HR RIDE',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  final otpController = TextEditingController();

  bool otpSent = false;
  String verificationId = '';

  Future<void> sendOTP() async {
    final phone = phoneController.text.trim();

    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10 digit mobile number')),
      );
      return;
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+91$phone',

      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        goHome();
      },

      verificationFailed: (FirebaseAuthException e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'OTP verification failed'),
          ),
        );
      },

      codeSent: (String id, int? resendToken) {
        setState(() {
          verificationId = id;
          otpSent = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent successfully')),
        );
      },

      codeAutoRetrievalTimeout: (String id) {
        verificationId = id;
      },
    );
  }

  Future<void> verifyOTP() async {
    if (otpController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter 6 digit OTP')),
      );
      return;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otpController.text.trim(),
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      goHome();
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Invalid OTP'),
        ),
      );
    }
  }

  void goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(),
      ),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HR RIDE',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_car,
              size: 90,
            ),

            const SizedBox(height: 20),

            const Text(
              'Welcome to HR RIDE',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Login / Sign Up with Mobile OTP',
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 35),

            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Mobile Number',
                hintText: 'Enter 10 digit number',
                prefixText: '+91 ',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            if (otpSent) ...[
              const SizedBox(height: 15),

              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Enter OTP',
                  hintText: '6 digit OTP',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: otpSent ? verifyOTP : sendOTP,
                child: Text(
                  otpSent ? 'VERIFY OTP' : 'SEND OTP',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HR RIDE',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_car,
              size: 100,
            ),

            const SizedBox(height: 20),

            const Text(
              'Welcome to HR Ride',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Your trusted ride service',
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 35),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BookingPage(),
                    ),
                  );
                },
                child: const Text(
                  'BOOK NOW',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final pickupController = TextEditingController();
  final dropController = TextEditingController();

  @override
  void dispose() {
    pickupController.dispose();
    dropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Your Ride'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pickup Location',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: pickupController,
              decoration: InputDecoration(
                hintText: 'Enter pickup location',
                prefixIcon: const Icon(Icons.my_location),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Drop Location',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: dropController,
              decoration: InputDecoration(
                hintText: 'Enter drop location',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Card(
              child: ListTile(
                leading: Icon(
                  Icons.directions_car,
                  size: 42,
                ),
                title: Text(
                  'Maruti Ertiga',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text('HR RIDE • West Bengal'),
                trailing: Text(
                  '22 km/l',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  if (pickupController.text.trim().isEmpty ||
                      dropController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter pickup and drop location',
                        ),
                      ),
                    );
                    return;
                  }

                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Booking Confirmed'),
                        content: Text(
                          'Pickup: ${pickupController.text}\n\n'
                          'Drop: ${dropController.text}\n\n'
                          'Vehicle: Maruti Ertiga',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text(
                  'CONFIRM BOOKING',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

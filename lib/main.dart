import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  try {
    await GoogleSignIn.instance.initialize(
  serverClientId: '383829745014-1m58ttp9dj4dqike8ot15uva7vnbajua.apps.googleusercontent.com',
);
  } catch (e) {
    debugPrint('Google Sign-In initialization error: $e');
  }

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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF071426),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1687FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// ============================================================
// LOGIN
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  final otpController = TextEditingController();

  bool otpSent = false;
  bool loading = false;
  String verificationId = '';

  Future<void> sendOTP() async {
    final input = phoneController.text.trim();

    if (input.isEmpty) {
      showError('Enter mobile number');
      return;
    }

    final phone = input.startsWith('+') ? input : '+91$input';

    if (!phone.startsWith('+')) {
      showError('Enter valid phone number');
      return;
    }

    if (loading) return;

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,

        verificationCompleted:
            (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(
              credential,
            );

            if (!mounted) return;

            setState(() => loading = false);
            goHome();
          } catch (e) {
            if (!mounted) return;

            setState(() => loading = false);
            showError('Firebase Error:\n$e');
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          setState(() => loading = false);

          showError(
            'Firebase OTP Error:\n'
            '${e.code}\n'
            '${e.message ?? ''}',
          );
        },

        codeSent: (
          String id,
          int? resendToken,
        ) {
          if (!mounted) return;

          setState(() {
            verificationId = id;
            otpSent = true;
            loading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP sent successfully'),
            ),
          );
        },

        codeAutoRetrievalTimeout: (String id) {
          verificationId = id;
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      showError('OTP Error:\n$e');
    }
  }

  Future<void> verifyOTP() async {
    final otp = otpController.text.trim();

    if (verificationId.isEmpty) {
      showError('Please request OTP again.');
      return;
    }

    if (otp.length != 6) {
      showError('Enter 6 digit OTP');
      return;
    }

    if (loading) return;

    setState(() => loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      if (!mounted) return;

      goHome();
    } on FirebaseAuthException catch (e) {
      showError(
        'Firebase Error:\n'
        '${e.code}\n'
        '${e.message ?? ''}',
      );
    } catch (e) {
      showError('OTP Verification Error:\n$e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> googleLogin() async {
    if (loading) return;

    setState(() => loading = true);

    try {
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google ID token is missing.');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      if (!mounted) return;

      goHome();
    } catch (e) {
      if (!mounted) return;

      showError('Google Login Error:\n$e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  void goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePage(),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 50),

              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFF1687FF),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x661687FF),
                      blurRadius: 30,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_car,
                  size: 62,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'HR RIDE',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'YOUR RIDE • OUR PRIORITY',
                style: TextStyle(
                  color: Color(0xFFB8C7D9),
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 45),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: '10 digit number',
                  prefixIcon: const Icon(Icons.phone),
                  filled: true,
                  fillColor: const Color(0xFF10243B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
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
                    labelText: 'OTP',
                    hintText: 'Enter 6 digit OTP',
                    prefixIcon: const Icon(Icons.lock),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFF10243B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed:
                      loading ? null : (otpSent ? verifyOTP : sendOTP),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1687FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: loading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : Text(
                          otpSent
                              ? 'VERIFY OTP'
                              : 'CONTINUE WITH OTP',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 25),

              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: OutlinedButton(
                  onPressed: loading ? null : googleLogin,
                  child: const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME
// ============================================================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const String adminPhone = '+16505551234';
  bool get isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user?.phoneNumber == adminPhone;
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
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Admin Panel',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminPanel(),
                  ),
                );
              },
            ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            const Text(
              'Welcome to HR RIDE',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Premium rides across West Bengal',
              style: TextStyle(
                color: Color(0xFF9EB1C7),
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 35),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1687FF),
                    Color(0xFF0B3D78),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.directions_car,
                    size: 62,
                    color: Colors.white,
                  ),
                  SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Maruti Ertiga',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Comfort • Safe • Reliable',
                        ),
                        SizedBox(height: 4),
                        Text(
                          '22 km/l • West Bengal',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BookingPage(),
                    ),
                  );
                },
                child: const Text(
                  'BOOK YOUR RIDE',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long),
                label: const Text(
                  'MY BOOKINGS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyBookingsPage(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 25),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF10243B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'HR RIDE SERVICE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Premium cab rental service across West Bengal.',
                    style: TextStyle(
                      color: Color(0xFF9EB1C7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BOOKING PAGE
// ============================================================

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final pickupController = TextEditingController();
  final dropController = TextEditingController();

  bool loading = false;

  Future<void> confirmBooking() async {
    final pickup = pickupController.text.trim();
    final drop = dropController.text.trim();

    if (pickup.isEmpty || drop.isEmpty) {
      showError('Please enter pickup and drop location');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showError('Please login first');
      return;
    }

    if (loading) return;

    setState(() => loading = true);

    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .add({
        'userId': user.uid,
        'userPhone': user.phoneNumber ?? '',
        'pickup': pickup,
        'drop': drop,
        'vehicle': 'Maruti Ertiga',
        'mileage': '22 km/l',
        'region': 'West Bengal',
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() => loading = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Booking Confirmed'),
          content: Text(
            'Pickup: $pickup\n\n'
            'Drop: $drop\n\n'
            'Vehicle: Maruti Ertiga\n'
            'Status: Pending',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      showError('Booking Error:\n$e');
    }
  }

  void showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

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
          children: [
            const SizedBox(height: 10),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Where are you going?',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 25),

            TextField(
              controller: pickupController,
              decoration: InputDecoration(
                labelText: 'Pickup Location',
                hintText: 'Enter pickup',
                prefixIcon: const Icon(Icons.my_location),
                filled: true,
                fillColor: const Color(0xFF10243B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 18),

            TextField(
              controller: dropController,
              decoration: InputDecoration(
                labelText: 'Drop Location',
                hintText: 'Enter destination',
                prefixIcon: const Icon(Icons.location_on),
                filled: true,
                fillColor: const Color(0xFF10243B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 25),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF10243B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.directions_car,
                    size: 50,
                    color: Color(0xFF1687FF),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maruti Ertiga',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text('HR RIDE • West Bengal'),
                      SizedBox(height: 3),
                      Text('22 km/l'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: loading ? null : confirmBooking,
                child: loading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text(
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

// ============================================================
// MY BOOKINGS
// ============================================================

class MyBookingsPage extends StatelessWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(
              child: Text('Please login first'),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where(
                    'userId',
                    isEqualTo: user.uid,
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                    ),
                  );
                }

                final docs =
                    snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No bookings yet'),
                  );
                }

                final bookings = [...docs];

                bookings.sort((a, b) {
                  final aTime =
                      (a.data()
                              as Map<String, dynamic>)['createdAt']
                          as Timestamp?;

                  final bTime =
                      (b.data()
                              as Map<String, dynamic>)['createdAt']
                          as Timestamp?;

                  return (bTime?.millisecondsSinceEpoch ?? 0)
                      .compareTo(
                    aTime?.millisecondsSinceEpoch ?? 0,
                  );
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final data = bookings[index].data()
                        as Map<String, dynamic>;

                    return BookingCard(
                      data: data,
                      bookingId: bookings[index].id,
                    );
                  },
                );
              },
            ),
    );
  }
}

class BookingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String bookingId;

  const BookingCard({
    super.key,
    required this.data,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context) {
    final status =
        data['status']?.toString() ?? 'Pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0B2942),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_car,
                color: Color(0xFF1687FF),
                size: 42,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Maruti Ertiga',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              StatusBadge(status: status),
            ],
          ),

          const SizedBox(height: 18),

          Text('Pickup: ${data['pickup'] ?? ''}'),
          const SizedBox(height: 10),
          Text('Drop: ${data['drop'] ?? ''}'),

          const SizedBox(height: 12),

          Text(
            '22 km/l • West Bengal',
            style: TextStyle(
              color: Colors.white.withOpacity(.65),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Booking ID: $bookingId',
            style: TextStyle(
              color: Colors.white.withOpacity(.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: status == 'Confirmed'
            ? Colors.green.withOpacity(.25)
            : status == 'Rejected'
                ? Colors.red.withOpacity(.25)
                : Colors.orange.withOpacity(.25),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: status == 'Confirmed'
              ? Colors.greenAccent
              : status == 'Rejected'
                  ? Colors.redAccent
                  : Colors.orangeAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ============================================================
// ADMIN PANEL
// ============================================================

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  static const String adminPhone = '+16505551234';

  bool get isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user?.phoneNumber == adminPhone;
  }

  Future<void> updateBooking(
    BuildContext context,
    String bookingId,
    String status,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking $status'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update Error:\n$e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
        ),
        body: const Center(
          child: Text(
            'Admin access denied',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HR RIDE ADMIN',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
              ),
            );
          }

          final docs =
              snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No bookings available',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];

              final data =
                  doc.data() as Map<String, dynamic>;

              final status =
                  data['status']?.toString() ?? 'Pending';

              return Container(
                margin:
                    const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF10243B),
                  borderRadius:
                      BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_car,
                          color: Color(0xFF1687FF),
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Maruti Ertiga',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                        StatusBadge(
                          status: status,
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Text(
                      'Pickup: ${data['pickup'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Drop: ${data['drop'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Customer: ${data['userPhone'] ?? ''}',
                      style: TextStyle(
                        color:
                            Colors.white.withOpacity(.65),
                      ),
                    ),

                    const SizedBox(height: 18),

                    if (status == 'Pending')
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                updateBooking(
                                  context,
                                  doc.id,
                                  'Confirmed',
                                );
                              },
                              icon: const Icon(
                                Icons.check,
                              ),
                              label:
                                  const Text('ACCEPT'),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                updateBooking(
                                  context,
                                  doc.id,
                                  'Rejected',
                                );
                              },
                              icon: const Icon(
                                Icons.close,
                              ),
                              label:
                                  const Text('REJECT'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

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
    await GoogleSignIn.instance.initialize();
  } catch (e) {
    debugPrint('Google Sign-In initialization error: $e');
  }

  runApp(const HRRideApp());
}

// ============================================================
// APP
// ============================================================

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
// LOGIN PAGE
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

  // ==========================================================
  // GOOGLE LOGIN
  // ==========================================================

  Future<void> googleLogin() async {
    if (loading) return;

    setState(() {
      loading = true;
    });

    try {
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final String? idToken = googleAuth.idToken;

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
    } on GoogleSignInException catch (e) {
      if (!mounted) return;

      showError(
        'Google Login Error:\n${e.code}',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      showError(
        'Firebase Error:\n'
        '${e.code}\n'
        '${e.message ?? ''}',
      );
    } catch (e) {
      if (!mounted) return;

      showError(
        'Google Login Error:\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================================
  // SEND OTP
  // ==========================================================

  Future<void> sendOTP() async {
    final input = phoneController.text.trim();

    final phone = input.startsWith('+')
        ? input
        : '+91$input';

    if (input.startsWith('+')) {
      if (input.length < 8) {
        showError(
          'Enter a valid phone number',
        );
        return;
      }
    } else {
      if (input.length != 10) {
        showError(
          'Enter a valid 10 digit mobile number',
        );
        return;
      }
    }

    if (loading) return;

    setState(() {
      loading = true;
    });

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

            setState(() {
              loading = false;
            });

            goHome();
          } on FirebaseAuthException catch (e) {
            if (!mounted) return;

            setState(() {
              loading = false;
            });

            showError(
              'Firebase Error:\n'
              '${e.code}\n'
              '${e.message ?? ''}',
            );
          }
        },

        verificationFailed:
            (FirebaseAuthException e) {
          if (!mounted) return;

          setState(() {
            loading = false;
          });

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
              content: Text(
                'OTP sent successfully',
              ),
            ),
          );
        },

        codeAutoRetrievalTimeout:
            (String id) {
          verificationId = id;
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showError(
        'Firebase Error:\n'
        '${e.code}\n'
        '${e.message ?? ''}',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showError(
        'OTP Error:\n$e',
      );
    }
  }

  // ==========================================================
  // VERIFY OTP
  // ==========================================================

  Future<void> verifyOTP() async {
    final otp = otpController.text.trim();

    if (verificationId.isEmpty) {
      showError(
        'Please request OTP again.',
      );
      return;
    }

    if (otp.length != 6) {
      showError(
        'Enter 6 digit OTP',
      );
      return;
    }

    if (loading) return;

    setState(() {
      loading = true;
    });

    try {
      final credential =
          PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      if (!mounted) return;

      goHome();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      showError(
        'Firebase Error:\n'
        '${e.code}\n'
        '${e.message ?? ''}',
      );
    } catch (e) {
      if (!mounted) return;

      showError(
        'OTP Verification Error:\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================================
  // ERROR
  // ==========================================================

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  // ==========================================================
  // GO HOME
  // ==========================================================

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

  // ==========================================================
  // LOGIN UI
  // ==========================================================

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
                  borderRadius:
                      BorderRadius.circular(30),
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
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 45),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 15,
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  hintText:
                      '10 digit or +country code',
                  prefixIcon:
                      const Icon(Icons.phone),
                  counterText: '',
                  filled: true,
                  fillColor:
                      const Color(0xFF10243B),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),

              if (otpSent) ...[
                const SizedBox(height: 15),

                TextField(
                  controller: otpController,
                  keyboardType:
                      TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'OTP',
                    hintText:
                        'Enter 6 digit OTP',
                    prefixIcon:
                        const Icon(Icons.lock),
                    counterText: '',
                    filled: true,
                    fillColor:
                        const Color(0xFF10243B),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(18),
                      borderSide:
                          BorderSide.none,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: loading
                      ? null
                      : (otpSent
                          ? verifyOTP
                          : sendOTP),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF1687FF),
                    foregroundColor:
                        Colors.white,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 25,
                          height: 25,
                          child:
                              CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          otpSent
                              ? 'VERIFY OTP'
                              : 'CONTINUE WITH OTP',
                          style:
                              const TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 25),

              const Row(
                children: [
                  Expanded(
                    child: Divider(),
                  ),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    child: Text('OR'),
                  ),
                  Expanded(
                    child: Divider(),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: OutlinedButton(
                  onPressed:
                      loading ? null : googleLogin,
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        Colors.white,
                    side: const BorderSide(
                      color: Color(0xFF38506A),
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.g_mobiledata,
                        size: 36,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 35),

              const Text(
                'Secure login powered by Firebase',
                style: TextStyle(
                  color: Color(0xFF71869D),
                  fontSize: 12,
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
// HOME PAGE
// ============================================================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  bool isAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    final phone = user?.phoneNumber ?? '';

    return phone == '+919002266005';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HR RIDE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (isAdmin())
            IconButton(
              icon: const Icon(
                Icons.admin_panel_settings,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const AdminBookingPage(),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(
              Icons.history,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const BookingHistoryPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
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
                gradient:
                    const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1687FF),
                    Color(0xFF0B3D78),
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x441687FF),
                    blurRadius: 20,
                  ),
                ],
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
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Comfort • Safe • Reliable',
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '22 km/l • West Bengal',
                          style: TextStyle(
                            color:
                                Color(0xFFD7E8FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const BookingPage(),
                    ),
                  );
                },
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF1687FF),
                  foregroundColor:
                      Colors.white,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'BOOK YOUR RIDE',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const BookingHistoryPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.history),
                label: const Text(
                  'MY BOOKINGS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:
                    const Color(0xFF10243B),
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'HR RIDE SERVICE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Premium cab rental service across West Bengal.',
                    style: TextStyle(
                      color:
                          Color(0xFF9EB1C7),
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
  State<BookingPage> createState() =>
      _BookingPageState();
}

class _BookingPageState
    extends State<BookingPage> {
  final pickupController =
      TextEditingController();

  final dropController =
      TextEditingController();

  bool saving = false;

  // ==========================================================
  // SAVE BOOKING
  // ==========================================================

  Future<void> confirmBooking() async {
    final pickup =
        pickupController.text.trim();

    final drop =
        dropController.text.trim();

    final user =
        FirebaseAuth.instance.currentUser;

    if (pickup.isEmpty || drop.isEmpty) {
      showMessage(
        'Please enter pickup and drop location',
      );
      return;
    }

    if (user == null) {
      showMessage(
        'Please login again.',
      );
      return;
    }

    if (saving) return;

    setState(() {
      saving = true;
    });

    try {
      final bookingRef =
          await FirebaseFirestore.instance
              .collection('bookings')
              .add({
        'userId': user.uid,
        'phone': user.phoneNumber ?? '',
        'pickup': pickup,
        'drop': drop,
        'vehicle': 'Maruti Ertiga',
        'serviceArea': 'West Bengal',
        'mileage': '22 km/l',
        'status': 'Pending',
        'createdAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        saving = false;
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
            title: const Text(
              'Booking Confirmed',
            ),
            content: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your booking has been saved.',
                ),
                const SizedBox(height: 15),
                Text(
                  'Booking ID:\n${bookingRef.id}',
                ),
                const SizedBox(height: 12),
                Text(
                  'Pickup: $pickup',
                ),
                const SizedBox(height: 8),
                Text(
                  'Drop: $drop',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vehicle: Maruti Ertiga',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Status: Pending',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('DONE'),
              ),
            ],
          );
        },
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      showMessage(
        'Booking Error:\n'
        '${e.code}\n'
        '${e.message ?? ''}',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      showMessage(
        'Booking Error:\n$e',
      );
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 7),
      ),
    );
  }

  @override
  void dispose() {
    pickupController.dispose();
    dropController.dispose();
    super.dispose();
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Book Your Ride',
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            const Text(
              'Where are you going?',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Enter your pickup and destination',
              style: TextStyle(
                color: Color(0xFF9EB1C7),
              ),
            ),

            const SizedBox(height: 28),

            TextField(
              controller: pickupController,
              decoration: InputDecoration(
                labelText:
                    'Pickup Location',
                hintText:
                    'Enter pickup',
                prefixIcon:
                    const Icon(
                  Icons.my_location,
                ),
                filled: true,
                fillColor:
                    const Color(0xFF10243B),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(18),
                  borderSide:
                      BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 18),

            TextField(
              controller: dropController,
              decoration: InputDecoration(
                labelText:
                    'Drop Location',
                hintText:
                    'Enter destination',
                prefixIcon:
                    const Icon(
                  Icons.location_on,
                ),
                filled: true,
                fillColor:
                    const Color(0xFF10243B),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(18),
                  borderSide:
                      BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 25),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color:
                    const Color(0xFF10243B),
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.directions_car,
                    size: 50,
                    color:
                        Color(0xFF1687FF),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Maruti Ertiga',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'HR RIDE • West Bengal',
                          style: TextStyle(
                            color:
                                Color(0xFF9EB1C7),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '22 km/l',
                          style: TextStyle(
                            color:
                                Color(0xFF1687FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed:
                    saving
                        ? null
                        : confirmBooking,
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF1687FF),
                  foregroundColor:
                      Colors.white,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 25,
                        height: 25,
                        child:
                            CircularProgressIndicator(
                          color:
                              Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        'CONFIRM BOOKING',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
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
// CUSTOMER BOOKING HISTORY
// ============================================================

class BookingHistoryPage
    extends StatelessWidget {
  const BookingHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title:
              const Text('My Bookings'),
        ),
        body: const Center(
          child: Text(
            'Please login again.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('My Bookings'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore
            .instance
            .collection('bookings')
            .where(
              'userId',
              isEqualTo: user.uid,
            )
            .snapshots(),
        builder:
            (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(20),
                child: Text(
                  'Error:\n${snapshot.error}',
                  textAlign:
                      TextAlign.center,
                ),
              ),
            );
          }

          final docs =
              snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 70,
                    color:
                        Color(0xFF1687FF),
                  ),
                  SizedBox(height: 15),
                  Text(
                    'No bookings yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          docs.sort((a, b) {
            final aData =
                a.data()
                    as Map<String, dynamic>;
            final bData =
                b.data()
                    as Map<String, dynamic>;

            final aTime =
                aData['createdAt'];
            final bTime =
                bData['createdAt'];

            if (aTime is Timestamp &&
                bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }

            return 0;
          });

          return ListView.builder(
            padding:
                const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder:
                (context, index) {
              final data =
                  docs[index].data()
                      as Map<String, dynamic>;

              return BookingCard(
                data: data,
                bookingId:
                    docs[index].id,
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// BOOKING CARD
// ============================================================

class BookingCard
    extends StatelessWidget {
  final Map<String, dynamic> data;
  final String bookingId;

  const BookingCard({
    super.key,
    required this.data,
    required this.bookingId,
  });

  Color statusColor(String status) {
    if (status == 'Confirmed') {
      return const Color(0xFF2ECC71);
    }

    if (status == 'Cancelled') {
      return const Color(0xFFE74C3C);
    }

    return const Color(0xFFFFB020);
  }

  @override
  Widget build(BuildContext context) {
    final status =
        data['status']?.toString() ??
            'Pending';

    final pickup =
        data['pickup']?.toString() ??
            '';

    final drop =
        data['drop']?.toString() ??
            '';

    return Container(
      margin:
          const EdgeInsets.only(bottom: 15),
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            const Color(0xFF10243B),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_taxi,
                color:
                    Color(0xFF1687FF),
                size: 32,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Maruti Ertiga',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      statusColor(status)
                          .withValues(
                    alpha: 0.15,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color:
                        statusColor(status),
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Text(
            'Pickup: $pickup',
            style:
                const TextStyle(
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Drop: $drop',
            style:
                const TextStyle(
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            '22 km/l • West Bengal',
            style:
                TextStyle(
              color:
                  Color(0xFF9EB1C7),
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'Booking ID: $bookingId',
            style:
                const TextStyle(
              color:
                  Color(0xFF71869D),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ADMIN BOOKING PAGE
// ============================================================

class AdminBookingPage
    extends StatelessWidget {
  const AdminBookingPage({super.key});

  Future<void> updateStatus(
    String bookingId,
    String status,
  ) async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({
      'status': status,
      'updatedAt':
          FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Admin Bookings'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore
            .instance
            .collection('bookings')
            .orderBy(
              'createdAt',
              descending: true,
            )
            .snapshots(),
        builder:
            (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(20),
                child: Text(
                  'Admin Error:\n${snapshot.error}',
                  textAlign:
                      TextAlign.center,
                ),
              ),
            );
          }

          final docs =
              snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No bookings found',
              ),
            );
          }

          return ListView.builder(
            padding:
                const EdgeInsets.all(15),
            itemCount: docs.length,
            itemBuilder:
                (context, index) {
              final doc =
                  docs[index];

              final data =
                  doc.data()
                      as Map<String, dynamic>;

              final status =
                  data['status']
                          ?.toString() ??
                      'Pending';

              return Container(
                margin:
                    const EdgeInsets.only(
                  bottom: 15,
                ),
                padding:
                    const EdgeInsets.all(18),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(0xFF10243B),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons
                              .admin_panel_settings,
                          color:
                              Color(0xFF1687FF),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Text(
                            'Booking #${index + 1}',
                            style:
                                const TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          status,
                          style:
                              const TextStyle(
                            color:
                                Color(0xFFFFB020),
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    Text(
                      'Customer: ${data['phone'] ?? 'N/A'}',
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    Text(
                      'Pickup: ${data['pickup'] ?? ''}',
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    Text(
                      'Drop: ${data['drop'] ?? ''}',
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    const Text(
                      'Vehicle: Maruti Ertiga',
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    Text(
                      'Booking ID: ${doc.id}',
                      style:
                          const TextStyle(
                        color:
                            Color(0xFF71869D),
                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                              ElevatedButton(
                            onPressed: () {
                              updateStatus(
                                doc.id,
                                'Confirmed',
                              );
                            },
                            style:
                                ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(
                                0xFF1687FF,
                              ),
                            ),
                            child:
                                const Text(
                              'CONFIRM',
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child:
                              OutlinedButton(
                            onPressed: () {
                              updateStatus(
                                doc.id,
                                'Cancelled',
                              );
                            },
                            child:
                                const Text(
                              'CANCEL',
                            ),
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

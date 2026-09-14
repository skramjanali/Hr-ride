import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase initialization
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Google Sign-In initialization
  try {
    await GoogleSignIn.instance.initialize();
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

    // যদি + দিয়ে international number দেওয়া হয়,
    // তাহলে সেটাই সরাসরি Firebase-এ যাবে।
    //
    // যেমন:
    // +16505551234
    //
    // আর যদি শুধু 10 digit India number দেওয়া হয়,
    // তাহলে +91 automatically যোগ হবে।
    final phone = input.startsWith('+')
        ? input
        : '+91$input';

    // International/test number validation
    if (input.startsWith('+')) {
      if (input.length < 8) {
        showError(
          'Enter a valid phone number',
        );
        return;
      }
    } else {
      // India mobile number validation
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

        // ------------------------------------------------------
        // AUTOMATIC VERIFICATION
        // ------------------------------------------------------

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

        // ------------------------------------------------------
        // VERIFICATION FAILED
        // ------------------------------------------------------

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

        // ------------------------------------------------------
        // CODE SENT
        // ------------------------------------------------------

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
              duration: Duration(seconds: 4),
            ),
          );
        },

        // ------------------------------------------------------
        // AUTO RETRIEVAL TIMEOUT
        // ------------------------------------------------------

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
  // ERROR MESSAGE
  // ==========================================================

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 10),
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

  // ==========================================================
  // DISPOSE
  // ==========================================================

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

              // LOGO
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

              // PHONE NUMBER
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 15,
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  hintText:
                      '10 digit number or +country code',
                  prefixIcon: const Icon(
                    Icons.phone,
                  ),
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

              // OTP FIELD
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

              // OTP BUTTON
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
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 25),

              // OR
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

              // GOOGLE BUTTON
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
                      width: 1.2,
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

            // CAR CARD
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

            // BOOK BUTTON
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
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            // SERVICE INFO
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

  // ==========================================================
  // CONFIRM BOOKING
  // ==========================================================

  void confirmBooking() {
    final pickup =
        pickupController.text.trim();

    final drop =
        dropController.text.trim();

    if (pickup.isEmpty || drop.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
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
      builder: (_) {
        return AlertDialog(
          title: const Text(
            'Booking Confirmed',
          ),
          content: Text(
            'Pickup: $pickup\n\n'
            'Drop: $drop\n\n'
            'Vehicle: Maruti Ertiga\n'
            'HR RIDE • West Bengal',
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
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    pickupController.dispose();
    dropController.dispose();
    super.dispose();
  }

  // ==========================================================
  // BOOKING UI
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

            // PICKUP
            TextField(
              controller: pickupController,
              decoration: InputDecoration(
                labelText: 'Pickup Location',
                hintText: 'Enter pickup',
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

            // DROP
            TextField(
              controller: dropController,
              decoration: InputDecoration(
                labelText: 'Drop Location',
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

            // VEHICLE CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
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

            // CONFIRM BUTTON
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed:
                    confirmBooking,
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
                  'CONFIRM BOOKING',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                    letterSpacing: 0.5,
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

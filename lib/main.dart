import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  try {
    await GoogleSignIn.instance.initialize(
      serverClientId:
          '383829745014-1m58ttp9dj4dqike8ot15uva7vnbajua.apps.googleusercontent.com',
    );
  } catch (e) {
    debugPrint('Google Sign-In initialization error: $e');
  }

  runApp(const HRRideApp());
}

// ============================================================
// CONFIG
// ============================================================

const String appName = 'HR RIDE';

const String adminPhone = '+16505551234';

const String backendUrl =
    'https://hr-ride.onrender.com';

const double acRate = 20.0;
const double nonAcRate = 17.0;
const double holdingRate = 100.0;

const double advancePercent = 0.30;

const String vehicleName =
    'Maruti Ertiga';

const String vehicleMileage =
    '22 km/l';

const String serviceRegion =
    'West Bengal';

// ============================================================
// APP
// ============================================================

class HRRideApp extends StatelessWidget {
  const HRRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor:
            const Color(0xFF101318),
        cardTheme: const CardThemeData(
          color: Color(0xFF191E25),
          elevation: 2,
        ),
        inputDecorationTheme:
            const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance
          .authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.data == null) {
          return const LoginPage();
        }

        return const HomePage();
      },
    );
  }
}

// ============================================================
// LOGIN
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}

class _LoginPageState
    extends State<LoginPage> {
  final phoneController =
      TextEditingController();

  final otpController =
      TextEditingController();

  String? verificationId;

  bool otpSent = false;
  bool loading = false;

  @override
  void dispose() {
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }

  String normalizedPhone() {
    final value =
        phoneController.text.trim();

    if (value.startsWith('+')) {
      return value;
    }

    if (value.startsWith('91') &&
        value.length == 12) {
      return '+$value';
    }

    return '+91$value';
  }

  Future<void> sendOtp() async {
    final phone =
        phoneController.text.trim();

    if (phone.isEmpty) {
      showMessage(
        'Enter mobile number',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await FirebaseAuth.instance
          .verifyPhoneNumber(
        phoneNumber: normalizedPhone(),

        verificationCompleted:
            (credential) async {
          try {
            await FirebaseAuth
                .instance
                .signInWithCredential(
                  credential,
                );
          } catch (e) {
            if (mounted) {
              showMessage(
                'Auto verification failed',
              );
            }
          }
        },

        verificationFailed:
            (error) {
          if (mounted) {
            showMessage(
              error.message ??
                  'OTP verification failed',
            );
          }
        },

        codeSent:
            (id, resendToken) {
          if (!mounted) return;

          setState(() {
            verificationId = id;
            otpSent = true;
          });

          showMessage(
            'OTP sent successfully',
          );
        },

        codeAutoRetrievalTimeout:
            (id) {
          verificationId = id;
        },
      );
    } catch (e) {
      showMessage(
        'OTP Error: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> verifyOtp() async {
    if (verificationId == null) {
      showMessage(
        'Send OTP first',
      );
      return;
    }

    final otp =
        otpController.text.trim();

    if (otp.length != 6) {
      showMessage(
        'Enter 6 digit OTP',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final credential =
          PhoneAuthProvider
              .credential(
        verificationId:
            verificationId!,
        smsCode: otp,
      );

      await FirebaseAuth.instance
          .signInWithCredential(
        credential,
      );
    } on FirebaseAuthException catch (e) {
      showMessage(
        e.message ??
            'Invalid OTP',
      );
    } catch (_) {
      showMessage(
        'Invalid OTP',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> googleLogin() async {
    setState(() {
      loading = true;
    });

    try {
      final account =
          await GoogleSignIn.instance
              .authenticate();

      final authentication =
          account.authentication;

      final idToken =
          authentication.idToken;

      if (idToken == null ||
          idToken.isEmpty) {
        throw Exception(
          'Google ID token unavailable',
        );
      }

      final credential =
          GoogleAuthProvider
              .credential(
        idToken: idToken,
      );

      await FirebaseAuth.instance
          .signInWithCredential(
        credential,
      );
    } catch (e) {
      showMessage(
        'Google Login Error: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child:
              SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.local_taxi_rounded,
                  size: 80,
                  color: Colors.blue,
                ),

                const SizedBox(
                  height: 16,
                ),

                const Text(
                  appName,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                const Text(
                  'Premium Cab Rental',
                  style: TextStyle(
                    color:
                        Colors.white70,
                  ),
                ),

                const SizedBox(
                  height: 35,
                ),

                TextField(
                  controller:
                      phoneController,
                  keyboardType:
                      TextInputType.phone,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Mobile Number',
                    hintText:
                        '+91XXXXXXXXXX',
                    prefixIcon:
                        Icon(Icons.phone),
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                if (otpSent)
                  TextField(
                    controller:
                        otpController,
                    keyboardType:
                        TextInputType
                            .number,
                    maxLength: 6,
                    decoration:
                        const InputDecoration(
                      labelText: 'OTP',
                      prefixIcon:
                          Icon(Icons.lock),
                      counterText: '',
                    ),
                  ),

                const SizedBox(
                  height: 10,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height: 52,
                  child:
                      FilledButton(
                    onPressed:
                        loading
                            ? null
                            : otpSent
                                ? verifyOtp
                                : sendOtp,
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : Text(
                            otpSent
                                ? 'VERIFY OTP'
                                : 'SEND OTP',
                          ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                const Text('OR'),

                const SizedBox(
                  height: 20,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height: 52,
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        loading
                            ? null
                            : googleLogin,
                    icon: const Icon(
                      Icons.login,
                    ),
                    label:
                        const Text(
                      'Continue with Google',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME
// ============================================================

class HomePage
    extends StatelessWidget {
  const HomePage({super.key});

  bool get isAdmin {
    final user =
        FirebaseAuth.instance
            .currentUser;

    return user?.phoneNumber ==
        adminPhone;
  }

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance
            .currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          appName,
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth
                  .instance
                  .signOut();
            },
            icon:
                const Icon(Icons.logout),
          ),
        ],
      ),
      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .stretch,
          children: [
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  18,
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      child:
                          Icon(Icons.person),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            user?.displayName ??
                                'HR RIDE Customer',
                            style:
                                const TextStyle(
                              fontSize:
                                  18,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            user?.phoneNumber ??
                                user?.email ??
                                '',
                            style:
                                const TextStyle(
                              color:
                                  Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            _MenuButton(
              icon:
                  Icons.local_taxi,
              title:
                  'Book HR RIDE',
              subtitle:
                  '$vehicleName • AC ₹$acRate/km',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const BookingPage(),
                  ),
                );
              },
            ),

            const SizedBox(
              height: 12,
            ),

            _MenuButton(
              icon:
                  Icons.receipt_long,
              title:
                  'My Bookings',
              subtitle:
                  'View bookings and trips',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const MyBookingsPage(),
                  ),
                );
              },
            ),

            if (isAdmin) ...[
              const SizedBox(
                height: 12,
              ),
              _MenuButton(
                icon: Icons
                    .admin_panel_settings,
                title:
                    'Admin Panel',
                subtitle:
                    'Accept, reject and manage bookings',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const AdminPanel(),
                    ),
                  );
                },
              ),

              const SizedBox(
                height: 12,
              ),

              _MenuButton(
                icon:
                    Icons.location_on,
                title:
                    'Driver Mode',
                subtitle:
                    'Live GPS and trip tracking',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const DriverModePage(),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuButton
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                child: Icon(icon),
              ),
              const SizedBox(
                width: 16,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        color:
                            Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BOOKING
// ============================================================

class BookingPage
    extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() =>
      _BookingPageState();
}

class _BookingPageState
    extends State<BookingPage> {
  final customerNameController =
      TextEditingController();

  final customerPhoneController =
      TextEditingController();

  final pickupController =
      TextEditingController();

  final dropController =
      TextEditingController();

  final distanceController =
      TextEditingController();

  final holdingController =
      TextEditingController(
    text: '0',
  );

  DateTime travelDate =
      DateTime.now();

  String vehicleType = 'AC';

  double calculatedDistance = 0;
  int? durationMinutes;

  bool calculatingDistance = false;
  bool booking = false;

  double get rate =>
      vehicleType == 'AC'
          ? acRate
          : nonAcRate;

  double get enteredKm =>
      double.tryParse(
        distanceController.text
            .trim(),
      ) ??
      0;

  double get holdingHours =>
      double.tryParse(
        holdingController.text
            .trim(),
      ) ??
      0;

  double get distanceFare =>
      enteredKm * rate;

  double get holdingFare =>
      holdingHours *
      holdingRate;

  double get totalFare =>
      distanceFare +
      holdingFare;

  double get advanceAmount =>
      totalFare *
      advancePercent;

  double get balanceAmount =>
      totalFare -
      advanceAmount;

  @override
  void dispose() {
    customerNameController.dispose();
    customerPhoneController.dispose();
    pickupController.dispose();
    dropController.dispose();
    distanceController.dispose();
    holdingController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // DISTANCE
  // ----------------------------------------------------------

  Future<void>
      calculateDistance() async {
    final pickup =
        pickupController.text.trim();

    final drop =
        dropController.text.trim();

    if (pickup.isEmpty) {
      showMessage(
        'Enter pickup location',
      );
      return;
    }

    if (drop.isEmpty) {
      showMessage(
        'Enter drop location',
      );
      return;
    }

    if (pickup.toLowerCase() ==
        drop.toLowerCase()) {
      showMessage(
        'Pickup and drop cannot be same',
      );
      return;
    }

    setState(() {
      calculatingDistance = true;
      calculatedDistance = 0;
      durationMinutes = null;
    });

    try {
      final response =
          await http.post(
        Uri.parse(
          '$backendUrl/api/route-distance',
        ),
        headers: {
          'Content-Type':
              'application/json',
        },
        body: jsonEncode({
          'pickup': pickup,
          'drop': drop,
        }),
      ).timeout(
        const Duration(
          seconds: 30,
        ),
      );

      if (response.statusCode !=
          200) {
        throw Exception(
          'Server returned ${response.statusCode}',
        );
      }

      final data =
          jsonDecode(response.body);

      if (data['success'] != true) {
        throw Exception(
          data['error'] ??
              'Distance calculation failed',
        );
      }

      final distance =
          (data['distanceKm'] as num?)
              ?.toDouble();

      final duration =
          (data['durationMinutes']
                  as num?)
              ?.toInt();

      if (distance == null ||
          distance <= 0) {
        throw Exception(
          'Invalid distance received',
        );
      }

      if (!mounted) return;

      setState(() {
        calculatedDistance =
            distance;
        durationMinutes =
            duration;

        distanceController.text =
            distance.toStringAsFixed(
          1,
        );
      });

      showMessage(
        'Distance: ${distance.toStringAsFixed(1)} KM',
      );
    } catch (e) {
      if (mounted) {
        showMessage(
          'Distance Error: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          calculatingDistance =
              false;
        });
      }
    }
  }

  // ----------------------------------------------------------
  // DATE
  // ----------------------------------------------------------

  Future<void> selectDate() async {
    final now = DateTime.now();

    final selected =
        await showDatePicker(
      context: context,
      firstDate: DateTime(
        now.year,
        now.month,
        now.day,
      ),
      lastDate: now.add(
        const Duration(
          days: 365,
        ),
      ),
      initialDate: travelDate,
    );

    if (selected != null) {
      setState(() {
        travelDate = selected;
      });
    }
  }

  // ----------------------------------------------------------
  // CREATE BOOKING
  // ----------------------------------------------------------

  Future<void>
      createBooking() async {
    final user =
        FirebaseAuth.instance
            .currentUser;

    if (user == null) {
      showMessage(
        'Please login first',
      );
      return;
    }

    final name =
        customerNameController.text
            .trim();

    final phone =
        customerPhoneController.text
            .trim();

    final pickup =
        pickupController.text.trim();

    final drop =
        dropController.text.trim();

    if (name.isEmpty) {
      showMessage(
        'Enter customer name',
      );
      return;
    }

    if (!RegExp(
      r'^[0-9]{10}$',
    ).hasMatch(phone)) {
      showMessage(
        'Enter valid 10 digit mobile number',
      );
      return;
    }

    if (pickup.isEmpty ||
        drop.isEmpty) {
      showMessage(
        'Enter pickup and drop',
      );
      return;
    }

    if (enteredKm <= 0) {
      showMessage(
        'Calculate route distance first',
      );
      return;
    }

    if (holdingHours < 0) {
      showMessage(
        'Holding hours cannot be negative',
      );
      return;
    }

    setState(() {
      booking = true;
    });

    try {
      final ref =
          await FirebaseFirestore
              .instance
              .collection('bookings')
              .add({
        'userId': user.uid,
        'userName': name,
        'userPhone': '+91$phone',
        'userEmail':
            user.email ?? '',

        'pickup': pickup,
        'drop': drop,

        'vehicle': vehicleName,
        'mileage': vehicleMileage,
        'region': serviceRegion,
        'vehicleType': vehicleType,

        'travelDate':
            Timestamp.fromDate(
          travelDate,
        ),

        'distanceKm': enteredKm,
        'chargeableKm': enteredKm,
        'durationMinutes':
            durationMinutes,

        'ratePerKm': rate,

        'holdingHours':
            holdingHours,
        'holdingRate':
            holdingRate,

        'distanceFare':
            distanceFare,
        'holdingFare':
            holdingFare,

        'totalAmount':
            totalFare,

        'advancePercent':
            advancePercent,

        'advanceAmount':
            advanceAmount,

        'balanceAmount':
            balanceAmount,

        'paymentStatus':
            'Pending',

        'paymentId': '',
        'orderId': '',

        'status': 'Pending',

        'createdAt':
            FieldValue
                .serverTimestamp(),

        'updatedAt':
            FieldValue
                .serverTimestamp(),
      });

      if (!mounted) return;

      await showBookingCreatedDialog(
        bookingId: ref.id,
      );
    } catch (e) {
      showMessage(
        'Booking Error: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          booking = false;
        });
      }
    }
  }

  Future<void>
      showBookingCreatedDialog({
    required String bookingId,
  }) async {
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text(
            'Booking Created',
          ),
          content:
              SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'Booking ID:\n$bookingId',
                ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                  'Vehicle: $vehicleName',
                ),
                Text(
                  'Type: $vehicleType',
                ),
                Text(
                  'Distance: '
                  '${enteredKm.toStringAsFixed(1)} KM',
                ),
                Text(
                  'Rate: ₹${rate.toStringAsFixed(0)}/KM',
                ),
                Text(
                  'Distance Fare: '
                  '₹${distanceFare.toStringAsFixed(0)}',
                ),
                Text(
                  'Holding: '
                  '₹${holdingFare.toStringAsFixed(0)}',
                ),
                const Divider(),
                Text(
                  'Total: '
                  '₹${totalFare.toStringAsFixed(0)}',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Advance 30%: '
                  '₹${advanceAmount.toStringAsFixed(0)}',
                ),
                Text(
                  'Balance 70%: '
                  '₹${balanceAmount.toStringAsFixed(0)}',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
                Navigator.pop(
                  context,
                );
              },
              child:
                  const Text('DONE'),
            ),
          ],
        );
      },
    );
  }

  void showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Book HR RIDE'),
      ),
      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .stretch,
          children: [
            TextField(
              controller:
                  customerNameController,
              textCapitalization:
                  TextCapitalization.words,
              decoration:
                  const InputDecoration(
                labelText:
                    'Customer Name',
                prefixIcon:
                    Icon(Icons.person),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            TextField(
              controller:
                  customerPhoneController,
              keyboardType:
                  TextInputType.phone,
              maxLength: 10,
              decoration:
                  const InputDecoration(
                labelText:
                    'Contact Number',
                hintText:
                    '10 digit mobile number',
                prefixIcon:
                    Icon(Icons.phone),
                counterText: '',
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            TextField(
              controller:
                  pickupController,
              textCapitalization:
                  TextCapitalization.words,
              decoration:
                  const InputDecoration(
                labelText:
                    'Pickup Location',
                prefixIcon:
                    Icon(Icons.location_on),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            TextField(
              controller:
                  dropController,
              textCapitalization:
                  TextCapitalization.words,
              decoration:
                  const InputDecoration(
                labelText:
                    'Drop Location',
                prefixIcon:
                    Icon(Icons.flag),
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            SizedBox(
              height: 50,
              child:
                  FilledButton.icon(
                onPressed:
                    calculatingDistance
                        ? null
                        : calculateDistance,
                icon:
                    calculatingDistance
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Icon(
                            Icons.route,
                          ),
                label: Text(
                  calculatingDistance
                      ? 'CALCULATING...'
                      : 'CALCULATE DISTANCE',
                ),
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            if (calculatedDistance >
                0)
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${calculatedDistance.toStringAsFixed(1)} KM',
                        style:
                            const TextStyle(
                          fontSize: 30,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      if (durationMinutes !=
                          null)
                        Text(
                          'Approx. '
                          '$durationMinutes minutes',
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(
              height: 12,
            ),

            const Text(
              'Vehicle Type',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            RadioListTile<String>(
              value: 'AC',
              groupValue:
                  vehicleType,
              onChanged: (value) {
                if (value == null)
                  return;

                setState(() {
                  vehicleType =
                      value;
                });
              },
              title: const Text(
                'AC - ₹20/KM',
              ),
            ),

            RadioListTile<String>(
              value: 'Non-AC',
              groupValue:
                  vehicleType,
              onChanged: (value) {
                if (value == null)
                  return;

                setState(() {
                  vehicleType =
                      value;
                });
              },
              title: const Text(
                'Non-AC - ₹17/KM',
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            TextField(
              controller:
                  holdingController,
              keyboardType:
                  const TextInputType
                      .numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) {
                setState(() {});
              },
              decoration:
                  const InputDecoration(
                labelText:
                    'Holding Hours',
                helperText:
                    '₹100 per hour',
                prefixIcon:
                    Icon(
                  Icons.access_time,
                ),
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            ListTile(
              leading:
                  const Icon(
                Icons.calendar_month,
              ),
              title: const Text(
                'Travel Date',
              ),
              subtitle: Text(
                '${travelDate.day}/'
                '${travelDate.month}/'
                '${travelDate.year}',
              ),
              trailing:
                  const Icon(
                Icons.edit,
              ),
              onTap: selectDate,
            ),

            const Divider(),

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Text(
                      'FARE SUMMARY',
                      style:
                          TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _FareRow(
                      label:
                          'Distance',
                      value:
                          '${enteredKm.toStringAsFixed(1)} KM',
                    ),

                    _FareRow(
                      label:
                          'Rate',
                      value:
                          '₹${rate.toStringAsFixed(0)}/KM',
                    ),

                    _FareRow(
                      label:
                          'Distance Fare',
                      value:
                          '₹${distanceFare.toStringAsFixed(0)}',
                    ),

                    _FareRow(
                      label:
                          'Holding',
                      value:
                          '₹${holdingFare.toStringAsFixed(0)}',
                    ),

                    const Divider(),

                    _FareRow(
                      label:
                          'TOTAL',
                      value:
                          '₹${totalFare.toStringAsFixed(0)}',
                      bold: true,
                    ),

                    _FareRow(
                      label:
                          'Advance 30%',
                      value:
                          '₹${advanceAmount.toStringAsFixed(0)}',
                    ),

                    _FareRow(
                      label:
                          'Balance 70%',
                      value:
                          '₹${balanceAmount.toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            SizedBox(
              height: 54,
              child:
                  FilledButton(
                onPressed:
                    booking
                        ? null
                        : createBooking,
                child: booking
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child:
                            CircularProgressIndicator(),
                      )
                    : const Text(
                        'CONFIRM BOOKING',
                        style:
                            TextStyle(
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
// FARE ROW
// ============================================================

class _FareRow
    extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _FareRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold
          ? FontWeight.bold
          : FontWeight.normal,
      fontSize: bold ? 17 : 14,
    );

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
        children: [
          Text(
            label,
            style: style,
          ),
          Text(
            value,
            style: style,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MY BOOKINGS
// ============================================================

class MyBookingsPage
    extends StatelessWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance
            .currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child:
              Text('Please login'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('My Bookings'),
      ),
      body:
          StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore
                .instance
                .collection('bookings')
                .where(
                  'userId',
                  isEqualTo:
                      user.uid,
                )
                .snapshots(),
        builder:
            (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final docs = snapshot
              .data!
              .docs
              .toList();

          docs.sort(
            (a, b) {
              final ad =
                  a.data()
                      as Map<String,
                          dynamic>;

              final bd =
                  b.data()
                      as Map<String,
                          dynamic>;

              final at =
                  ad['createdAt']
                      as Timestamp?;

              final bt =
                  bd['createdAt']
                      as Timestamp?;

              return (bt
                          ?.millisecondsSinceEpoch ??
                      0)
                  .compareTo(
                at?.millisecondsSinceEpoch ??
                    0,
              );
            },
          );

          if (docs.isEmpty) {
            return const Center(
              child:
                  Text('No bookings yet'),
            );
          }

          return ListView.builder(
            padding:
                const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder:
                (context, index) {
              return BookingCard(
                doc: docs[index],
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
  final QueryDocumentSnapshot doc;

  const BookingCard({
    super.key,
    required this.doc,
  });

  @override
  Widget build(BuildContext context) {
    final data =
        doc.data()
            as Map<String, dynamic>;

    final status =
        data['status'] ??
            'Pending';

    final paymentStatus =
        data['paymentStatus'] ??
            'Pending';

    final total =
        toDouble(
      data['totalAmount'],
    );

    final advance =
        toDouble(
      data['advanceAmount'],
    );

    final balance =
        toDouble(
      data['balanceAmount'],
    );

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_taxi,
                  color:
                      Colors.blue,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    data['vehicle'] ??
                        vehicleName,
                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    status.toString(),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              '👤 ${data['userName'] ?? ''}',
            ),

            Text(
              '📞 ${data['userPhone'] ?? ''}',
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              '📍 ${data['pickup'] ?? ''}',
            ),

            Text(
              '🏁 ${data['drop'] ?? ''}',
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              'Distance: '
              '${data['distanceKm'] ?? 0} KM',
            ),

            Text(
              'Total: '
              '₹${total.toStringAsFixed(0)}',
            ),

            Text(
              'Advance 30%: '
              '₹${advance.toStringAsFixed(0)}',
            ),

            Text(
              'Balance: '
              '₹${balance.toStringAsFixed(0)}',
            ),

            Text(
              'Payment: '
              '$paymentStatus',
            ),

            if (status ==
                    'Confirmed' ||
                status ==
                    'Trip Started')
              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 12,
                ),
                child: SizedBox(
                  width:
                      double.infinity,
                  child:
                      FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomerTrackingPage(
                            bookingId:
                                doc.id,
                          ),
                        ),
                      );
                    },
                    icon:
                        const Icon(
                      Icons.location_on,
                    ),
                    label:
                        const Text(
                      'TRACK DRIVER',
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
// ADMIN PANEL
// ============================================================

class AdminPanel
    extends StatelessWidget {
  const AdminPanel({super.key});

  Future<void> updateStatus(
    String id,
    String status,
  ) async {
    await FirebaseFirestore
        .instance
        .collection('bookings')
        .doc(id)
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
            const Text('Admin Panel'),
      ),
      body:
          StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore
                .instance
                .collection('bookings')
                .snapshots(),
        builder:
            (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final docs =
              snapshot.data!.docs.toList();

          docs.sort(
            (a, b) {
              final ad =
                  a.data()
                      as Map<String,
                          dynamic>;

              final bd =
                  b.data()
                      as Map<String,
                          dynamic>;

              final at =
                  ad['createdAt']
                      as Timestamp?;

              final bt =
                  bd['createdAt']
                      as Timestamp?;

              return (bt
                          ?.millisecondsSinceEpoch ??
                      0)
                  .compareTo(
                at?.millisecondsSinceEpoch ??
                    0,
              );
            },
          );

          if (docs.isEmpty) {
            return const Center(
              child:
                  Text('No bookings'),
            );
          }

          return ListView.builder(
            padding:
                const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder:
                (context, index) {
              final doc = docs[index];

              final data =
                  doc.data()
                      as Map<String,
                          dynamic>;

              final status =
                  data['status'] ??
                      'Pending';

              return Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    15,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        data['userName'] ??
                            'Customer',
                        style:
                            const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      Text(
                        '📞 ${data['userPhone'] ?? ''}',
                      ),

                      if ((data['userEmail'] ??
                              '')
                          .toString()
                          .isNotEmpty)
                        Text(
                          '📧 ${data['userEmail']}',
                        ),

                      const SizedBox(
                        height: 8,
                      ),

                      Text(
                        'Pickup: '
                        '${data['pickup'] ?? ''}',
                      ),

                      Text(
                        'Drop: '
                        '${data['drop'] ?? ''}',
                      ),

                      Text(
                        'Vehicle: '
                        '${data['vehicle'] ?? vehicleName}',
                      ),

                      Text(
                        'Type: '
                        '${data['vehicleType'] ?? 'AC'}',
                      ),

                      Text(
                        'Distance: '
                        '${data['distanceKm'] ?? 0} KM',
                      ),

                      Text(
                        'Total: '
                        '₹${data['totalAmount'] ?? 0}',
                      ),

                      Text(
                        'Advance: '
                        '₹${data['advanceAmount'] ?? 0}',
                      ),

                      Text(
                        'Payment: '
                        '${data['paymentStatus'] ?? 'Pending'}',
                      ),

                      Text(
                        'Status: $status',
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      if (status ==
                          'Pending')
                        Row(
                          children: [
                            Expanded(
                              child:
                                  FilledButton(
                                onPressed:
                                    () async {
                                  await updateStatus(
                                    doc.id,
                                    'Confirmed',
                                  );
                                },
                                child:
                                    const Text(
                                  'ACCEPT',
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child:
                                  OutlinedButton(
                                onPressed:
                                    () async {
                                  await updateStatus(
                                    doc.id,
                                    'Rejected',
                                  );
                                },
                                child:
                                    const Text(
                                  'REJECT',
                                ),
                              ),
                            ),
                          ],
                        ),

                      if (status ==
                          'Confirmed')
                        SizedBox(
                          width:
                              double.infinity,
                          child:
                              OutlinedButton.icon(
                            onPressed:
                                () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const DriverModePage(),
                                ),
                              );
                            },
                            icon:
                                const Icon(
                              Icons
                                  .location_on,
                            ),
                            label:
                                const Text(
                              'OPEN DRIVER MODE',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// DRIVER MODE
// ============================================================

class DriverModePage
    extends StatefulWidget {
  const DriverModePage({super.key});

  @override
  State<DriverModePage> createState() =>
      _DriverModePageState();
}

class _DriverModePageState
    extends State<DriverModePage> {
  final MapController mapController =
      MapController();

  StreamSubscription<Position>?
      positionSubscription;

  Position? currentPosition;
  Position? previousPosition;

  String? activeBookingId;

  bool online = false;
  bool starting = false;

  double liveDistanceKm = 0;

  DateTime? lastFirestoreUpdate;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    super.dispose();
  }

  Future<bool>
      checkLocationPermission() async {
    final enabled =
        await Geolocator
            .isLocationServiceEnabled();

    if (!enabled) {
      showMessage(
        'Please turn ON GPS/Location',
      );
      return false;
    }

    var permission =
        await Geolocator
            .checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator
              .requestPermission();
    }

    if (permission ==
            LocationPermission.denied ||
        permission ==
            LocationPermission
                .deniedForever) {
      showMessage(
        'Location permission is required',
      );
      return false;
    }

    return true;
  }

  Future<void>
      startDriverMode() async {
    if (online) return;

    final allowed =
        await checkLocationPermission();

    if (!allowed) return;

    setState(() {
      starting = true;
    });

    try {
      final position =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
          distanceFilter: 5,
        ),
      );

      final user =
          FirebaseAuth.instance
              .currentUser;

      if (user == null) {
        throw Exception(
          'Driver not logged in',
        );
      }

      currentPosition =
          position;

      await FirebaseFirestore
          .instance
          .collection(
            'driverLocations',
          )
          .doc(user.uid)
          .set({
        'driverUid': user.uid,
        'latitude':
            position.latitude,
        'longitude':
            position.longitude,
        'heading':
            position.heading,
        'speed':
            position.speed,
        'online': true,
        'activeBookingId':
            activeBookingId,
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      }, SetOptions(
        merge: true,
      ));

      await positionSubscription
          ?.cancel();

      positionSubscription =
          Geolocator
              .getPositionStream(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        onPositionChanged,
        onError: (error) {
          showMessage(
            'GPS Error: $error',
          );
        },
      );

      if (!mounted) return;

      setState(() {
        online = true;
      });

      mapController.move(
        LatLng(
          position.latitude,
          position.longitude,
        ),
        15,
      );
    } catch (e) {
      showMessage(
        'Driver Mode Error: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          starting = false;
        });
      }
    }
  }

  Future<void>
      onPositionChanged(
    Position position,
  ) async {
    if (!mounted) return;

    setState(() {
      currentPosition =
          position;
    });

    if (activeBookingId != null &&
        previousPosition != null) {
      final meters =
          Geolocator.distanceBetween(
        previousPosition!.latitude,
        previousPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      if (meters > 1 &&
          meters < 1000) {
        liveDistanceKm +=
            meters / 1000;
      }
    }

    if (activeBookingId != null) {
      previousPosition =
          position;
    }

    try {
      mapController.move(
        LatLng(
          position.latitude,
          position.longitude,
        ),
        mapController.camera.zoom,
      );
    } catch (_) {}

    final now = DateTime.now();

    if (lastFirestoreUpdate ==
            null ||
        now.difference(
              lastFirestoreUpdate!,
            ) >=
            const Duration(
              seconds: 3,
            )) {
      lastFirestoreUpdate =
          now;

      await updateDriverLocation(
        position,
      );
    }
  }

  Future<void>
      updateDriverLocation(
    Position position,
  ) async {
    final user =
        FirebaseAuth.instance
            .currentUser;

    if (user == null) return;

    await FirebaseFirestore
        .instance
        .collection(
          'driverLocations',
        )
        .doc(user.uid)
        .set({
      'driverUid': user.uid,
      'latitude':
          position.latitude,
      'longitude':
          position.longitude,
      'heading':
          position.heading,
      'speed':
          position.speed,
      'online': online,
      'activeBookingId':
          activeBookingId,
      'updatedAt':
          FieldValue
              .serverTimestamp(),
    }, SetOptions(
      merge: true,
    ));

    if (activeBookingId != null) {
      await FirebaseFirestore
          .instance
          .collection(
            'liveTrips',
          )
          .doc(
            activeBookingId!,
          )
          .set({
        'bookingId':
            activeBookingId,
        'driverUid':
            user.uid,
        'latitude':
            position.latitude,
        'longitude':
            position.longitude,
        'heading':
            position.heading,
        'speed':
            position.speed,
        'liveDistanceKm':
            liveDistanceKm,
        'status':
            'started',
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      }, SetOptions(
        merge: true,
      ));
    }
  }

  Future<void> startTrip(
    String bookingId,
  ) async {
    if (activeBookingId != null) {
      showMessage(
        'Another trip is already active',
      );
      return;
    }

    if (!online) {
      await startDriverMode();

      if (!mounted || !online) {
        return;
      }
    }

    final user =
        FirebaseAuth.instance
            .currentUser;

    if (user == null) return;

    try {
      final snapshot =
          await FirebaseFirestore
              .instance
              .collection(
                'bookings',
              )
              .doc(
                bookingId,
              )
              .get();

      final data =
          snapshot.data();

      if (data == null) {
        showMessage(
          'Booking not found',
        );
        return;
      }

      if (data['status'] !=
          'Confirmed') {
        showMessage(
          'Booking is not confirmed',
        );
        return;
      }

      final position =
          currentPosition ??
              await Geolocator
                  .getCurrentPosition();

      setState(() {
        activeBookingId =
            bookingId;
        liveDistanceKm = 0;
        previousPosition =
            position;
      });

      await FirebaseFirestore
          .instance
          .collection(
            'liveTrips',
          )
          .doc(bookingId)
          .set({
        'bookingId':
            bookingId,
        'driverUid':
            user.uid,
        'customerName':
            data['userName'] ?? '',
        'customerPhone':
            data['userPhone'] ?? '',
        'pickup':
            data['pickup'] ?? '',
        'drop':
            data['drop'] ?? '',
        'vehicle':
            data['vehicle'] ??
                vehicleName,
        'vehicleType':
            data['vehicleType'] ??
                'AC',
        'ratePerKm':
            data['ratePerKm'] ??
                acRate,
        'holdingHours':
            data['holdingHours'] ??
                0,
        'holdingRate':
            holdingRate,
        'latitude':
            position.latitude,
        'longitude':
            position.longitude,
        'heading':
            position.heading,
        'speed':
            position.speed,
        'liveDistanceKm': 0,
        'status': 'started',
        'startedAt':
            FieldValue
                .serverTimestamp(),
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      }, SetOptions(
        merge: true,
      ));

      await FirebaseFirestore
          .instance
          .collection(
            'bookings',
          )
          .doc(bookingId)
          .update({
        'status':
            'Trip Started',
        'tripStartedAt':
            FieldValue
                .serverTimestamp(),
        'driverUid':
            user.uid,
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      });

      showMessage(
        'TRIP STARTED 🚕',
      );
    } catch (e) {
      showMessage(
        'Start Trip Error: $e',
      );
    }
  }

  Future<void> endTrip() async {
    final bookingId =
        activeBookingId;

    if (bookingId == null) {
      showMessage(
        'No active trip',
      );
      return;
    }

    try {
      final tripRef =
          FirebaseFirestore
              .instance
              .collection(
                'liveTrips',
              )
              .doc(
                bookingId,
              );

      final snapshot =
          await tripRef.get();

      final data =
          snapshot.data();

      final rate =
          toDouble(
        data?['ratePerKm'],
        fallback: acRate,
      );

      final holding =
          toDouble(
        data?['holdingHours'],
      );

      final finalDistance =
          liveDistanceKm;

      final distanceFare =
          finalDistance * rate;

      final holdingFare =
          holding *
              holdingRate;

      final total =
          distanceFare +
              holdingFare;

      final advance =
          total * advancePercent;

      final balance =
          total - advance;

      await tripRef.set({
        'liveDistanceKm':
            finalDistance,
        'distanceFare':
            distanceFare,
        'holdingFare':
            holdingFare,
        'totalAmount':
            total,
        'advanceAmount':
            advance,
        'balanceAmount':
            balance,
        'status':
            'completed',
        'endedAt':
            FieldValue
                .serverTimestamp(),
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      }, SetOptions(
        merge: true,
      ));

      await FirebaseFirestore
          .instance
          .collection(
            'bookings',
          )
          .doc(bookingId)
          .update({
        'status':
            'Completed',
        'finalDistanceKm':
            finalDistance,
        'finalDistanceFare':
            distanceFare,
        'finalHoldingFare':
            holdingFare,
        'finalTotalAmount':
            total,
        'finalAdvanceAmount':
            advance,
        'finalBalanceAmount':
            balance,
        'tripEndedAt':
            FieldValue
                .serverTimestamp(),
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      });

      final user =
          FirebaseAuth.instance
              .currentUser;

      if (user != null) {
        await FirebaseFirestore
            .instance
            .collection(
              'driverLocations',
            )
            .doc(user.uid)
            .set({
          'activeBookingId': null,
          'online': true,
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        }, SetOptions(
          merge: true,
        ));
      }

      setState(() {
        activeBookingId = null;
        liveDistanceKm = 0;
        previousPosition =
            null;
      });

      await showDialog(
        context: context,
        builder: (_) =>
            AlertDialog(
          title:
              const Text(
            'Trip Completed',
          ),
          content:
              Text(
            'Final Distance: '
            '${finalDistance.toStringAsFixed(2)} KM\n\n'
            'Distance Fare: '
            '₹${distanceFare.toStringAsFixed(0)}\n'
            'Holding: '
            '₹${holdingFare.toStringAsFixed(0)}\n\n'
            'Total: '
            '₹${total.toStringAsFixed(0)}\n'
            'Advance 30%: '
            '₹${advance.toStringAsFixed(0)}\n'
            'Balance 70%: '
            '₹${balance.toStringAsFixed(0)}',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
              ),
              child:
                  const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      showMessage(
        'End Trip Error: $e',
      );
    }
  }

  Future<void>
      stopDriverMode() async {
    if (activeBookingId != null) {
      showMessage(
        'End the active trip first',
      );
      return;
    }

    await positionSubscription
        ?.cancel();

    positionSubscription =
        null;

    final user =
        FirebaseAuth.instance
            .currentUser;

    if (user != null) {
      await FirebaseFirestore
          .instance
          .collection(
            'driverLocations',
          )
          .doc(user.uid)
          .set({
        'online': false,
        'activeBookingId': null,
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      }, SetOptions(
        merge: true,
      ));
    }

    if (mounted) {
      setState(() {
        online = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Driver Mode'),
        actions: [
          if (online)
            IconButton(
              onPressed:
                  stopDriverMode,
              icon: const Icon(
                Icons
                    .power_settings_new,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                FlutterMap(
                  mapController:
                      mapController,
                  options:
                      const MapOptions(
                    initialCenter:
                        LatLng(
                      23.6850,
                      87.6856,
                    ),
                    initialZoom: 8,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'com.hrride.app',
                    ),

                    if (currentPosition !=
                        null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point:
                                LatLng(
                              currentPosition!
                                  .latitude,
                              currentPosition!
                                  .longitude,
                            ),
                            width: 55,
                            height: 55,
                            child:
                                Transform.rotate(
                              angle:
                                  currentPosition!
                                          .heading *
                                      math.pi /
                                      180,
                              child:
                                  const Icon(
                                Icons
                                    .navigation,
                                size: 42,
                                color:
                                    Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration:
                                BoxDecoration(
                              shape:
                                  BoxShape
                                      .circle,
                              color: online
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            online
                                ? 'DRIVER ONLINE'
                                : 'DRIVER OFFLINE',
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 5,
            child:
                StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore
                      .instance
                      .collection(
                        'bookings',
                      )
                      .where(
                        'status',
                        whereIn: const [
                          'Confirmed',
                          'Trip Started',
                        ],
                      )
                      .snapshots(),
              builder:
                  (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: '
                      '${snapshot.error}',
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                final docs =
                    snapshot.data!.docs;

                return Column(
                  children: [
                    if (activeBookingId !=
                        null)
                      Card(
                        margin:
                            const EdgeInsets.all(
                          10,
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets.all(
                            14,
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'ACTIVE TRIP',
                                style:
                                    TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),

                              const SizedBox(
                                height: 8,
                              ),

                              Text(
                                '${liveDistanceKm.toStringAsFixed(2)} KM',
                                style:
                                    const TextStyle(
                                  fontSize: 24,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),

                              const Text(
                                'Live Distance',
                              ),

                              const SizedBox(
                                height: 10,
                              ),

                              SizedBox(
                                width:
                                    double.infinity,
                                child:
                                    FilledButton
                                        .icon(
                                  onPressed:
                                      endTrip,
                                  icon:
                                      const Icon(
                                    Icons.stop,
                                  ),
                                  label:
                                      const Text(
                                    'END TRIP',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    Expanded(
                      child:
                          ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        itemCount:
                            docs.length,
                        itemBuilder:
                            (context, index) {
                          final doc =
                              docs[index];

                          final data =
                              doc.data()
                                  as Map<String,
                                      dynamic>;

                          final isActive =
                              doc.id ==
                                  activeBookingId;

                          return Card(
                            child:
                                ListTile(
                              leading:
                                  const Icon(
                                Icons.local_taxi,
                                color:
                                    Colors.blue,
                              ),
                              title:
                                  Text(
                                data['userName'] ??
                                    'Customer',
                              ),
                              subtitle:
                                  Text(
                                '📞 ${data['userPhone'] ?? ''}\n'
                                '${data['pickup'] ?? ''} → '
                                '${data['drop'] ?? ''}\n'
                                '${data['vehicleType'] ?? 'AC'} • '
                                '${data['distanceKm'] ?? 0} KM',
                              ),
                              isThreeLine:
                                  true,
                              trailing:
                                  isActive
                                      ? const Chip(
                                          label:
                                              Text(
                                            'ACTIVE',
                                          ),
                                        )
                                      : activeBookingId ==
                                              null &&
                                          data['status'] ==
                                              'Confirmed'
                                          ? FilledButton(
                                              onPressed:
                                                  () =>
                                                      startTrip(
                                                doc.id,
                                              ),
                                              child:
                                                  const Text(
                                                'START',
                                              ),
                                            )
                                          : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton:
          !online
              ? FloatingActionButton.extended(
                  onPressed:
                      starting
                          ? null
                          : startDriverMode,
                  icon: starting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                          ),
                        )
                      : const Icon(
                          Icons.play_arrow,
                        ),
                  label: Text(
                    starting
                        ? 'STARTING...'
                        : 'GO ONLINE',
                  ),
                )
              : null,
    );
  }

  void showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}

// ============================================================
// CUSTOMER LIVE TRACKING
// ============================================================

class CustomerTrackingPage
    extends StatefulWidget {
  final String bookingId;

  const CustomerTrackingPage({
    super.key,
    required this.bookingId,
  });

  @override
  State<CustomerTrackingPage>
      createState() =>
          _CustomerTrackingPageState();
}

class _CustomerTrackingPageState
    extends State<
        CustomerTrackingPage> {
  final MapController mapController =
      MapController();

  LatLng? driverLocation;

  double liveDistanceKm = 0;
  double rate = acRate;
  double holdingHours = 0;

  String status = 'waiting';

  String customerName = '';
  String customerPhone = '';

  StreamSubscription<
          DocumentSnapshot>?
      tripSubscription;

  @override
  void initState() {
    super.initState();

    tripSubscription =
        FirebaseFirestore
            .instance
            .collection(
              'liveTrips',
            )
            .doc(
              widget.bookingId,
            )
            .snapshots()
            .listen(
      (snapshot) {
        final data =
            snapshot.data();

        if (data == null) return;

        final lat =
            toNullableDouble(
          data['latitude'],
        );

        final lng =
            toNullableDouble(
          data['longitude'],
        );

        if (lat == null ||
            lng == null) {
          if (mounted) {
            setState(() {
              status =
                  data['status'] ??
                      'waiting';
            });
          }
          return;
        }

        final location =
            LatLng(lat, lng);

        if (!mounted) return;

        setState(() {
          driverLocation =
              location;

          liveDistanceKm =
              toDouble(
            data['liveDistanceKm'],
          );

          rate =
              toDouble(
            data['ratePerKm'],
            fallback: acRate,
          );

          holdingHours =
              toDouble(
            data['holdingHours'],
          );

          customerName =
              data['customerName'] ??
                  '';

          customerPhone =
              data['customerPhone'] ??
                  '';

          status =
              data['status'] ??
                  'waiting';
        });

        try {
          mapController.move(
            location,
            15,
          );
        } catch (_) {}
      },
    );
  }

  @override
  void dispose() {
    tripSubscription?.cancel();
    super.dispose();
  }

  double get distanceFare =>
      liveDistanceKm * rate;

  double get holdingFare =>
      holdingHours *
      holdingRate;

  double get totalFare =>
      distanceFare +
      holdingFare;

  double get advance =>
      totalFare *
      advancePercent;

  double get balance =>
      totalFare - advance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Live Driver Tracking',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: FlutterMap(
              mapController:
                  mapController,
              options:
                  const MapOptions(
                initialCenter:
                    LatLng(
                  23.6850,
                  87.6856,
                ),
                initialZoom: 8,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'com.hrride.app',
                ),

                if (driverLocation !=
                    null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point:
                            driverLocation!,
                        width: 70,
                        height: 70,
                        child: Container(
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape.circle,
                            color: Colors.blue
                                .withValues(
                              alpha: 0.2,
                            ),
                          ),
                          child:
                              const Icon(
                            Icons.local_taxi,
                            size: 42,
                            color:
                                Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          Expanded(
            flex: 4,
            child: Card(
              margin:
                  const EdgeInsets.all(
                10,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,
                  children: [
                    if (customerName
                        .isNotEmpty)
                      Text(
                        customerName,
                        style:
                            const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                    if (customerPhone
                        .isNotEmpty)
                      Text(
                        customerPhone,
                      ),

                    const SizedBox(
                      height: 8,
                    ),

                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color:
                              status ==
                                      'completed'
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                        const SizedBox(
                          width: 7,
                        ),
                        Text(
                          status ==
                                  'completed'
                              ? 'TRIP COMPLETED'
                              : status ==
                                      'started'
                                  ? 'DRIVER ON THE WAY'
                                  : 'WAITING FOR DRIVER',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Text(
                      'Live Distance: '
                      '${liveDistanceKm.toStringAsFixed(2)} KM',
                      style:
                          const TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    Text(
                      'Distance Fare: '
                      '₹${distanceFare.toStringAsFixed(0)}',
                    ),

                    Text(
                      'Holding: '
                      '₹${holdingFare.toStringAsFixed(0)}',
                    ),

                    const Divider(),

                    Text(
                      'LIVE BILL: '
                      '₹${totalFare.toStringAsFixed(0)}',
                      style:
                          const TextStyle(
                        fontSize: 19,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    Text(
                      'Advance 30%: '
                      '₹${advance.toStringAsFixed(0)}',
                    ),

                    Text(
                      'Balance 70%: '
                      '₹${balance.toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

double toDouble(
  dynamic value, {
  double fallback = 0,
}) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value) ??
        fallback;
  }

  return fallback;
}

double? toNullableDouble(
  dynamic value,
) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}

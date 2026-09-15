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

const String adminPhone = '+16505551234';
const String backendUrl = 'https://hr-ride.onrender.com';

const double acRate = 20;
const double nonAcRate = 17;
const double holdingRate = 100;

// ============================================================
// APP
// ============================================================

class HRRideApp extends StatelessWidget {
  const HRRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HR RIDE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF101318),
        cardTheme: const CardThemeData(
          color: Color(0xFF191E25),
          elevation: 2,
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
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
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
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  final otpController = TextEditingController();

  String? verificationId;
  bool otpSent = false;
  bool loading = false;

  @override
  void dispose() {
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }

  Future<void> sendOtp() async {
    final phone = phoneController.text.trim();

    if (phone.isEmpty) {
      showMessage('Enter mobile number');
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone.startsWith('+')
            ? phone
            : '+91$phone',
        verificationCompleted: (credential) async {
          await FirebaseAuth.instance
              .signInWithCredential(credential);
        },
        verificationFailed: (error) {
          if (mounted) {
            showMessage(
              error.message ??
                  'OTP verification failed',
            );
          }
        },
        codeSent: (id, _) {
          if (!mounted) return;

          setState(() {
            verificationId = id;
            otpSent = true;
          });

          showMessage('OTP sent successfully');
        },
        codeAutoRetrievalTimeout: (id) {
          verificationId = id;
        },
      );
    } catch (e) {
      showMessage('OTP Error: $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> verifyOtp() async {
    if (verificationId == null) {
      showMessage('Send OTP first');
      return;
    }

    final otp = otpController.text.trim();

    if (otp.length < 6) {
      showMessage('Enter 6 digit OTP');
      return;
    }

    setState(() => loading = true);

    try {
      final credential =
          PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otp,
      );

      await FirebaseAuth.instance
          .signInWithCredential(credential);
    } catch (e) {
      showMessage('Invalid OTP');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> googleLogin() async {
    setState(() => loading = true);

    try {
      final account =
          await GoogleSignIn.instance.authenticate();

      final authentication =
          account.authentication;

      final credential =
          GoogleAuthProvider.credential(
        idToken: authentication.idToken,
      );

      await FirebaseAuth.instance
          .signInWithCredential(credential);
    } catch (e) {
      showMessage('Google Login Error: $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.local_taxi_rounded,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 15),
                const Text(
                  'HR RIDE',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Premium Cab Rental',
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 35),

                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: '+91XXXXXXXXXX',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 15),

                if (otpSent)
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'OTP',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading
                        ? null
                        : otpSent
                            ? verifyOtp
                            : sendOtp,
                    child: loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            otpSent
                                ? 'VERIFY OTP'
                                : 'SEND OTP',
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text('OR'),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        loading ? null : googleLogin,
                    icon: const Icon(Icons.login),
                    label: const Text(
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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  bool get isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user?.phoneNumber == adminPhone;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HR RIDE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      child: Icon(Icons.person),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ??
                                'HR RIDE Customer',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.phoneNumber ??
                                user?.email ??
                                '',
                            style: const TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            _MenuButton(
              icon: Icons.local_taxi,
              title: 'Book HR RIDE',
              subtitle: 'Maruti Ertiga Cab',
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

            const SizedBox(height: 12),

            _MenuButton(
              icon: Icons.receipt_long,
              title: 'My Bookings',
              subtitle:
                  'View your bookings and trips',
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

            const SizedBox(height: 12),

            if (isAdmin) ...[
              _MenuButton(
                icon:
                    Icons.admin_panel_settings,
                title: 'Admin Panel',
                subtitle:
                    'Manage bookings',
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
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.location_on,
                title: 'Driver Mode',
                subtitle:
                    'Live GPS & Trip Tracking',
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

class _MenuButton extends StatelessWidget {
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
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                child: Icon(icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
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

  // Customer details
  final customerNameController =
      TextEditingController();

  final customerPhoneController =
      TextEditingController();

  // Trip details
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

  DateTime travelDate = DateTime.now();

  String vehicleType = 'AC';

  double calculatedDistance = 0;
  int? durationMinutes;

  bool calculatingDistance = false;
  bool booking = false;

  double get rate =>
      vehicleType == 'AC'
          ? acRate
          : nonAcRate;

  double get enteredKm {
    return double.tryParse(
          distanceController.text.trim(),
        ) ??
        0;
  }

  double get holdingHours {
    return double.tryParse(
          holdingController.text.trim(),
        ) ??
        0;
  }

  double get chargeableKm =>
      enteredKm;

  double get distanceFare =>
      chargeableKm * rate;

  double get holdingFare =>
      holdingHours * holdingRate;

  double get totalFare =>
      distanceFare + holdingFare;

  double get advanceAmount =>
      totalFare * 0.30;

  double get balanceAmount =>
      totalFare - advanceAmount;

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

  // ==========================================================
  // DISTANCE
  // ==========================================================

  Future<void> calculateDistance() async {
    final pickup =
        pickupController.text.trim();

    final drop =
        dropController.text.trim();

    if (pickup.isEmpty) {
      showError(
        'Enter pickup location',
      );
      return;
    }

    if (drop.isEmpty) {
      showError(
        'Enter drop location',
      );
      return;
    }

    if (pickup.toLowerCase() ==
        drop.toLowerCase()) {
      showError(
        'Pickup and drop cannot be the same.',
      );
      return;
    }

    if (calculatingDistance) return;

    setState(() {
      calculatingDistance = true;
      calculatedDistance = 0;
      durationMinutes = null;
    });

    try {
      final response = await http.post(
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
      );

      if (response.statusCode != 200) {
        String message =
            'Distance calculation failed.';

        try {
          final data =
              jsonDecode(response.body);

          if (data is Map &&
              data['error'] != null) {
            message =
                data['error'].toString();
          }
        } catch (_) {}

        throw Exception(message);
      }

      final data =
          jsonDecode(response.body);

      if (data['success'] != true) {
        throw Exception(
          data['error'] ??
              'Distance calculation failed.',
        );
      }

      final distance =
          (data['distanceKm'] as num?)
              ?.toDouble();

      final duration =
          (data['durationMinutes'] as num?)
              ?.toInt();

      if (distance == null ||
          distance <= 0) {
        throw Exception(
          'Valid distance was not returned.',
        );
      }

      if (!mounted) return;

      setState(() {
        calculatedDistance = distance;
        durationMinutes = duration;
        distanceController.text =
            distance.toStringAsFixed(1);
      });

      showMessage(
        'Distance: '
        '${distance.toStringAsFixed(1)} KM',
      );
    } catch (e) {
      if (!mounted) return;

      showError(
        'Distance Error:\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          calculatingDistance = false;
        });
      }
    }
  }

  // ==========================================================
  // DATE
  // ==========================================================

  Future<void> selectDate() async {
    final selected =
        await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate:
          DateTime.now().add(
        const Duration(days: 365),
      ),
      initialDate: travelDate,
    );

    if (selected != null) {
      setState(() {
        travelDate = selected;
      });
    }
  }

  // ==========================================================
  // CREATE BOOKING
  // ==========================================================

  Future<void> createBooking() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      showError(
        'Please login first',
      );
      return;
    }

    final customerName =
        customerNameController
            .text
            .trim();

    final customerPhone =
        customerPhoneController
            .text
            .trim();

    if (customerName.isEmpty) {
      showError(
        'Enter customer name',
      );
      return;
    }

    if (customerPhone.length != 10 ||
        int.tryParse(customerPhone) ==
            null) {
      showError(
        'Enter valid 10 digit contact number',
      );
      return;
    }

    if (pickupController.text
            .trim()
            .isEmpty ||
        dropController.text
            .trim()
            .isEmpty) {
      showError(
        'Enter pickup and drop',
      );
      return;
    }

    if (enteredKm <= 0) {
      showError(
        'Calculate route distance first.',
      );
      return;
    }

    setState(() {
      booking = true;
    });

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('bookings')
              .add({
        // Customer
        'userId': user.uid,
        'userName': customerName,
        'userPhone':
            '+91$customerPhone',
        'userEmail':
            user.email ?? '',

        // Route
        'pickup':
            pickupController.text.trim(),
        'drop':
            dropController.text.trim(),

        // Vehicle
        'vehicle':
            'Maruti Ertiga',
        'mileage':
            '22 km/l',
        'region':
            'West Bengal',
        'vehicleType':
            vehicleType,

        // Date
        'travelDate':
            Timestamp.fromDate(
          travelDate,
        ),

        // Distance
        'distanceKm':
            enteredKm,
        'chargeableKm':
            chargeableKm,

        // Rates
        'ratePerKm':
            rate,
        'holdingHours':
            holdingHours,
        'holdingRate':
            holdingRate,

        // Fare
        'distanceFare':
            distanceFare,
        'holdingFare':
            holdingFare,
        'totalAmount':
            totalFare,
        'advanceAmount':
            advanceAmount,
        'balanceAmount':
            balanceAmount,

        // Payment
        'paymentStatus':
            'Pending',
        'paymentId':
            '',
        'orderId':
            '',

        // Status
        'status':
            'Pending',

        'createdAt':
            FieldValue
                .serverTimestamp(),
      });

      if (!mounted) return;

      showBillDialog(
        bookingId: doc.id,
        customerName:
            customerName,
        customerPhone:
            '+91$customerPhone',
      );
    } catch (e) {
      showError(
        'Booking Error:\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          booking = false;
        });
      }
    }
  }

  // ==========================================================
  // BILL
  // ==========================================================

  void showBillDialog({
    required String bookingId,
    required String customerName,
    required String customerPhone,
  }) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title:
              const Text(
            'Booking Created',
          ),
          content:
              SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer: '
                  '$customerName',
                ),
                Text(
                  'Contact: '
                  '$customerPhone',
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  'Booking ID:\n'
                  '$bookingId',
                ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                  'Distance: '
                  '${enteredKm.toStringAsFixed(1)} KM',
                ),
                Text(
                  'Rate: '
                  '₹${rate.toStringAsFixed(0)}/KM',
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

  void showError(
    String message,
  ) {
    showMessage(message);
  }

  // ==========================================================
  // BOOKING UI
  // ==========================================================

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

            // CUSTOMER NAME
            TextField(
              controller:
                  customerNameController,
              textCapitalization:
                  TextCapitalization
                      .words,
              decoration:
                  const InputDecoration(
                labelText:
                    'Customer Name',
                hintText:
                    'Enter customer name',
                prefixIcon:
                    Icon(Icons.person),
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // CUSTOMER PHONE
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
                border:
                    OutlineInputBorder(),
                counterText: '',
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // PICKUP
            TextField(
              controller:
                  pickupController,
              decoration:
                  const InputDecoration(
                labelText:
                    'Pickup Location',
                prefixIcon:
                    Icon(Icons.location_on),
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // DROP
            TextField(
              controller:
                  dropController,
              decoration:
                  const InputDecoration(
                labelText:
                    'Drop Location',
                prefixIcon:
                    Icon(Icons.flag),
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // DISTANCE
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
                            height: 18,
                            width: 18,
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
              height: 18,
            ),

            if (calculatedDistance >
                0)
              Card(
                child:
                    Padding(
                  padding:
                      const EdgeInsets
                          .all(16),
                  child:
                      Column(
                    children: [
                      Text(
                        '${calculatedDistance.toStringAsFixed(1)} KM',
                        style:
                            const TextStyle(
                          fontSize:
                              30,
                          fontWeight:
                              FontWeight
                                  .bold,
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
              height: 15,
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
              onChanged:
                  (value) {
                if (value ==
                    null) {
                  return;
                }

                setState(() {
                  vehicleType =
                      value;
                });
              },
              title:
                  const Text(
                'AC - ₹20/KM',
              ),
            ),

            RadioListTile<String>(
              value: 'Non-AC',
              groupValue:
                  vehicleType,
              onChanged:
                  (value) {
                if (value ==
                    null) {
                  return;
                }

                setState(() {
                  vehicleType =
                      value;
                });
              },
              title:
                  const Text(
                'Non-AC - ₹17/KM',
              ),
            ),

            // HOLDING
            TextField(
              controller:
                  holdingController,
              keyboardType:
                  const TextInputType
                      .numberWithOptions(
                decimal: true,
              ),
              decoration:
                  const InputDecoration(
                labelText:
                    'Holding Hours',
                prefixIcon:
                    Icon(
                  Icons.access_time,
                ),
                helperText:
                    '₹100 per hour',
                border:
                    OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),

            const SizedBox(
              height: 12,
            ),

            // DATE
            ListTile(
              leading:
                  const Icon(
                Icons.calendar_month,
              ),
              title:
                  const Text(
                'Travel Date',
              ),
              subtitle:
                  Text(
                '${travelDate.day}/'
                '${travelDate.month}/'
                '${travelDate.year}',
              ),
              trailing:
                  const Icon(
                Icons.edit,
              ),
              onTap:
                  selectDate,
            ),

            const Divider(),

            // FARE
            Card(
              child:
                  Padding(
                padding:
                    const EdgeInsets
                        .all(16),
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Text(
                      'FARE SUMMARY',
                      style:
                          TextStyle(
                        fontSize:
                            18,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),

                    _FareRow(
                      label:
                          'Distance',
                      value:
                          '${chargeableKm.toStringAsFixed(1)} KM',
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
              height: 15,
            ),

            SizedBox(
              height: 54,
              child:
                  FilledButton(
                onPressed:
                    booking
                        ? null
                        : createBooking,
                child:
                    booking
                        ? const CircularProgressIndicator()
                        : const Text(
                            'CONFIRM BOOKING',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
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
  Widget build(
    BuildContext context,
  ) {
    final style =
        TextStyle(
      fontWeight:
          bold
              ? FontWeight.bold
              : FontWeight.normal,
      fontSize:
          bold ? 17 : 14,
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
  Widget build(
    BuildContext context,
  ) {
    final user =
        FirebaseAuth.instance
            .currentUser;

    if (user == null) {
      return const Scaffold(
        body:
            Center(
          child:
              Text(
            'Please login',
          ),
        ),
      );
    }

    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          'My Bookings',
        ),
      ),
      body:
          StreamBuilder<
              QuerySnapshot>(
        stream:
            FirebaseFirestore
                .instance
                .collection(
                  'bookings',
                )
                .where(
                  'userId',
                  isEqualTo:
                      user.uid,
                )
                .snapshots(),
        builder:
            (context, snapshot) {
          if (snapshot
              .hasError) {
            return Center(
              child:
                  Text(
                'Error: '
                '${snapshot.error}',
              ),
            );
          }

          if (!snapshot
              .hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final docs =
              snapshot
                  .data!
                  .docs
                  .toList();

          docs.sort(
            (a, b) {
              final aData =
                  a.data()
                      as Map<String,
                          dynamic>;

              final bData =
                  b.data()
                      as Map<String,
                          dynamic>;

              final aTime =
                  aData[
                          'createdAt']
                      as Timestamp?;

              final bTime =
                  bData[
                          'createdAt']
                      as Timestamp?;

              return (bTime
                          ?.millisecondsSinceEpoch ??
                      0)
                  .compareTo(
                aTime?.millisecondsSinceEpoch ??
                    0,
              );
            },
          );

          if (docs.isEmpty) {
            return const Center(
              child:
                  Text(
                'No bookings yet',
              ),
            );
          }

          return ListView.builder(
            padding:
                const EdgeInsets
                    .all(12),
            itemCount:
                docs.length,
            itemBuilder:
                (context, index) {
              return BookingCard(
                doc:
                    docs[index],
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
  Widget build(
    BuildContext context,
  ) {
    final data =
        doc.data()
            as Map<String,
                dynamic>;

    final status =
        data['status'] ??
            'Pending';

    final total =
        ((data[
                    'totalAmount'] ??
                0) as num)
            .toDouble();

    final advance =
        ((data[
                    'advanceAmount'] ??
                0) as num)
            .toDouble();

    return Card(
      child:
          Padding(
        padding:
            const EdgeInsets
                .all(16),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
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
                  child:
                      Text(
                    data[
                            'vehicle'] ??
                        'Maruti Ertiga',
                    style:
                        const TextStyle(
                      fontSize:
                          17,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                ),
                Chip(
                  label:
                      Text(
                    status
                        .toString(),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              '👤 Customer: '
              '${data['userName'] ?? ''}',
            ),

            Text(
              '📞 Contact: '
              '${data['userPhone'] ?? ''}',
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              '📍 '
              '${data['pickup'] ?? ''}',
            ),

            Text(
              '🏁 '
              '${data['drop'] ?? ''}',
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
              'Advance: '
              '₹${advance.toStringAsFixed(0)}',
            ),

            if (status ==
                'Confirmed')
              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 12,
                ),
                child:
                    SizedBox(
                  width:
                      double.infinity,
                  child:
                      FilledButton.icon(
                    icon:
                        const Icon(
                      Icons.location_on,
                    ),
                    label:
                        const Text(
                      'TRACK DRIVER',
                    ),
                    onPressed:
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  CustomerTrackingPage(
                            bookingId:
                                doc.id,
                          ),
                        ),
                      );
                    },
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
  const AdminPanel({
    super.key,
  });

  Future<void> updateStatus(
    String id,
    String status,
  ) async {
    await FirebaseFirestore
        .instance
        .collection(
          'bookings',
        )
        .doc(id)
        .update({
      'status':
          status,
      'updatedAt':
          FieldValue
              .serverTimestamp(),
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          'Admin Panel',
        ),
      ),
      body:
          StreamBuilder<
              QuerySnapshot>(
        stream:
            FirebaseFirestore
                .instance
                .collection(
                  'bookings',
                )
                .snapshots(),
        builder:
            (context, snapshot) {
          if (snapshot
              .hasError) {
            return Center(
              child:
                  Text(
                'Error: '
                '${snapshot.error}',
              ),
            );
          }

          if (!snapshot
              .hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final docs =
              snapshot
                  .data!
                  .docs
                  .toList();

          docs.sort(
            (a, b) {
              final aData =
                  a.data()
                      as Map<String,
                          dynamic>;

              final bData =
                  b.data()
                      as Map<String,
                          dynamic>;

              final aTime =
                  aData[
                          'createdAt']
                      as Timestamp?;

              final bTime =
                  bData[
                          'createdAt']
                      as Timestamp?;

              return (bTime
                          ?.millisecondsSinceEpoch ??
                      0)
                  .compareTo(
                aTime?.millisecondsSinceEpoch ??
                    0,
              );
            },
          );

          if (docs.isEmpty) {
            return const Center(
              child:
                  Text(
                'No bookings',
              ),
            );
          }

          return ListView.builder(
            padding:
                const EdgeInsets
                    .all(12),
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

              final status =
                  data[
                          'status'] ??
                      'Pending';

              return Card(
                child:
                    Padding(
                  padding:
                      const EdgeInsets
                          .all(15),
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        data[
                                'userName'] ??
                            'Customer',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight
                                  .bold,
                          fontSize:
                              18,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        '📞 Contact: '
                        '${data['userPhone'] ?? ''}',
                      ),

                      if ((data[
                                      'userEmail'] ??
                                  '')
                              .toString()
                              .isNotEmpty)
                        Text(
                          '📧 Email: '
                          '${data['userEmail']}',
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
                        '${data['vehicle'] ?? 'Maruti Ertiga'}',
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
                        'Status: '
                        '$status',
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
                                    () =>
                                        updateStatus(
                                  doc.id,
                                  'Confirmed',
                                ),
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
                                    () =>
                                        updateStatus(
                                  doc.id,
                                  'Rejected',
                                ),
                                child:
                                    const Text(
                                  'REJECT',
                                ),
                              ),
                            ),
                          ],
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
  const DriverModePage({
    super.key,
  });

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

  String? activeBookingId;

  bool online = false;
  bool starting = false;

  double liveDistanceKm = 0;

  Position? previousPosition;

  DateTime? lastFirestoreUpdate;

  @override
  void initState() {
    super.initState();
    checkLocationPermission();
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
        'Please turn ON Location/GPS',
      );
      return false;
    }

    LocationPermission
        permission =
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
        'Location permission is required.',
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
        ),
      );

      final user =
          FirebaseAuth
              .instance
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
        'online':
            true,
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      }, SetOptions(
        merge: true,
      ));

      positionSubscription =
          Geolocator
              .getPositionStream(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
          distanceFilter:
              5,
        ),
      ).listen(
        onPositionChanged,
      );

      if (mounted) {
        setState(() {
          online = true;
        });
      }

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

    if (previousPosition !=
            null &&
        activeBookingId !=
            null) {

      final meters =
          Geolocator
              .distanceBetween(
        previousPosition!
            .latitude,
        previousPosition!
            .longitude,
        position.latitude,
        position.longitude,
      );

      if (meters > 1 &&
          meters < 1000) {
        liveDistanceKm +=
            meters / 1000;
      }
    }

    if (activeBookingId !=
        null) {
      previousPosition =
          position;
    }

    mapController.move(
      LatLng(
        position.latitude,
        position.longitude,
      ),
      mapController.camera
          .zoom,
    );

    final now =
        DateTime.now();

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
      'online':
          online,
      'activeBookingId':
          activeBookingId,
      'updatedAt':
          FieldValue
              .serverTimestamp(),
    }, SetOptions(
      merge: true,
    ));

    if (activeBookingId !=
        null) {
      await FirebaseFirestore
          .instance
          .collection(
            'liveTrips',
          )
          .doc(
            activeBookingId,
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

    if (!online) {
      await startDriverMode();

      if (!online) return;
    }

    final user =
        FirebaseAuth.instance
            .currentUser;

    if (user == null) return;

    final bookingSnapshot =
        await FirebaseFirestore
            .instance
            .collection(
              'bookings',
            )
            .doc(
              bookingId,
            )
            .get();

    final bookingData =
        bookingSnapshot.data();

    if (bookingData == null) {
      showMessage(
        'Booking not found',
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
        .doc(
          bookingId,
        )
        .set({
      'bookingId':
          bookingId,
      'driverUid':
          user.uid,
      'customerName':
          bookingData[
              'userName'],
      'customerPhone':
          bookingData[
              'userPhone'],
      'pickup':
          bookingData[
              'pickup'] ??
              '',
      'drop':
          bookingData[
              'drop'] ??
              '',
      'vehicle':
          bookingData[
                  'vehicle'] ??
              'Maruti Ertiga',
      'vehicleType':
          bookingData[
                  'vehicleType'] ??
              'AC',
      'ratePerKm':
          bookingData[
                  'ratePerKm'] ??
              acRate,
      'holdingHours':
          bookingData[
                  'holdingHours'] ??
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
      'liveDistanceKm':
          0,
      'status':
          'started',
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
        .doc(
          bookingId,
        )
        .update({
      'status':
          'Trip Started',
      'tripStartedAt':
          FieldValue
              .serverTimestamp(),
    });

    showMessage(
      'TRIP STARTED 🚕',
    );
  }

  Future<void> endTrip() async {

    final bookingId =
        activeBookingId;

    if (bookingId == null) {
      return;
    }

    final finalDistance =
        liveDistanceKm;

    final tripRef =
        FirebaseFirestore
            .instance
            .collection(
              'liveTrips',
            )
            .doc(
              bookingId,
            );

    final tripSnapshot =
        await tripRef.get();

    final data =
        tripSnapshot.data();

    final rate =
        ((data?[
                        'ratePerKm'] ??
                    acRate)
                as num)
            .toDouble();

    final holdingHours =
        ((data?[
                        'holdingHours'] ??
                    0)
                as num)
            .toDouble();

    final distanceFare =
        finalDistance * rate;

    final holdingFare =
        holdingHours *
            holdingRate;

    final total =
        distanceFare +
            holdingFare;

    final advance =
        total * 0.30;

    final balance =
        total - advance;

    await tripRef.update({
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
    });

    await FirebaseFirestore
        .instance
        .collection(
          'bookings',
        )
        .doc(
          bookingId,
        )
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
    });

    setState(() {
      activeBookingId =
          null;
      liveDistanceKm = 0;
      previousPosition =
          null;
    });

    showDialog(
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
          '${finalDistance.toStringAsFixed(1)} KM\n\n'
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
  }

  Future<void>
      stopDriverMode() async {

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
        'online':
            false,
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

  double tripBill(
    Map<String, dynamic>
        booking,
  ) {

    final rate =
        ((booking[
                    'ratePerKm'] ??
                acRate)
            as num)
        .toDouble();

    final holding =
        ((booking[
                    'holdingHours'] ??
                0)
            as num)
        .toDouble();

    return liveDistanceKm *
            rate +
        holding *
            holdingRate;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          'Driver Mode',
        ),
        actions: [
          if (online)
            IconButton(
              onPressed:
                  stopDriverMode,
              icon:
                  const Icon(
                Icons
                    .power_settings_new,
              ),
            ),
        ],
      ),
      body:
          Column(
        children: [

          // MAP
          Expanded(
            flex: 5,
            child:
                Stack(
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
                    initialZoom:
                        8,
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
                            width:
                                55,
                            height:
                                55,
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
                                size:
                                    42,
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
                  child:
                      Card(
                    child:
                        Padding(
                      padding:
                          const EdgeInsets
                              .all(12),
                      child:
                          Row(
                        children: [
                          Container(
                            width:
                                12,
                            height:
                                12,
                            decoration:
                                BoxDecoration(
                              shape:
                                  BoxShape
                                      .circle,
                              color: online
                                  ? Colors
                                      .green
                                  : Colors
                                      .red,
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

          // BOOKINGS / ACTIVE TRIP
          Expanded(
            flex: 4,
            child:
                StreamBuilder<
                    QuerySnapshot>(
              stream:
                  FirebaseFirestore
                      .instance
                      .collection(
                        'bookings',
                      )
                      .where(
                        'status',
                        isEqualTo:
                            'Confirmed',
                      )
                      .snapshots(),
              builder:
                  (context,
                      snapshot) {

                if (!snapshot
                    .hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                final docs =
                    snapshot
                        .data!
                        .docs;

                return Column(
                  children: [

                    if (activeBookingId !=
                        null)
                      Card(
                        margin:
                            const EdgeInsets
                                .all(10),
                        child:
                            Padding(
                          padding:
                              const EdgeInsets
                                  .all(14),
                          child:
                              Column(
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
                                height:
                                    8,
                              ),

                              Text(
                                'Live Distance: '
                                '${liveDistanceKm.toStringAsFixed(2)} KM',
                                style:
                                    const TextStyle(
                                  fontSize:
                                      20,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),

                              const SizedBox(
                                height:
                                    5,
                              ),

                              if (docs
                                  .isNotEmpty)
                                Text(
                                  'Live Bill: '
                                  '₹${tripBill(
                                    docs.first
                                            .data()
                                        as Map<String,
                                            dynamic>,
                                  ).toStringAsFixed(0)}',
                                ),

                              const SizedBox(
                                height:
                                    10,
                              ),

                              SizedBox(
                                width:
                                    double.infinity,
                                child:
                                    FilledButton.icon(
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
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              10,
                        ),
                        itemCount:
                            docs.length,
                        itemBuilder:
                            (context,
                                index) {

                          final doc =
                              docs[index];

                          final data =
                              doc.data()
                                  as Map<String,
                                      dynamic>;

                          return Card(
                            child:
                                ListTile(
                              leading:
                                  const Icon(
                                Icons
                                    .local_taxi,
                                color:
                                    Colors.blue,
                              ),
                              title:
                                  Text(
                                '${data['userName'] ?? 'Customer'}',
                              ),
                              subtitle:
                                  Text(
                                '📞 ${data['userPhone'] ?? ''}\n'
                                '${data['pickup'] ?? ''} → '
                                '${data['drop'] ?? ''}\n'
                                '${data['vehicleType'] ?? 'AC'} • '
                                '${data['distanceKm'] ?? 0} KM • '
                                '₹${data['totalAmount'] ?? 0}',
                              ),
                              isThreeLine:
                                  true,
                              trailing:
                                  activeBookingId ==
                                          null
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
              ? FloatingActionButton
                  .extended(
                  onPressed:
                      starting
                          ? null
                          : startDriverMode,
                  icon:
                      starting
                          ? const SizedBox(
                              width:
                                  18,
                              height:
                                  18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .play_arrow,
                            ),
                  label:
                      Text(
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
        content:
            Text(message),
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

  final MapController
      mapController =
      MapController();

  LatLng? driverLocation;

  double liveDistanceKm = 0;

  double rate = acRate;

  double holdingHours = 0;

  String status =
      'waiting';

  String customerName =
      '';

  String customerPhone =
      '';

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

        if (data == null) {
          return;
        }

        final lat =
            (data[
                        'latitude']
                    as num?)
                ?.toDouble();

        final lng =
            (data[
                        'longitude']
                    as num?)
                ?.toDouble();

        if (lat != null &&
            lng != null) {

          final location =
              LatLng(
            lat,
            lng,
          );

          if (!mounted) return;

          setState(() {
            driverLocation =
                location;

            liveDistanceKm =
                ((data[
                            'liveDistanceKm'] ??
                        0)
                    as num)
                    .toDouble();

            rate =
                ((data[
                            'ratePerKm'] ??
                        acRate)
                    as num)
                    .toDouble();

            holdingHours =
                ((data[
                            'holdingHours'] ??
                        0)
                    as num)
                    .toDouble();

            customerName =
                data[
                        'customerName'] ??
                    '';

            customerPhone =
                data[
                        'customerPhone'] ??
                    '';

            status =
                data[
                        'status'] ??
                    'waiting';
          });

          mapController.move(
            location,
            15,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    tripSubscription
        ?.cancel();
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
      totalFare * 0.30;

  double get balance =>
      totalFare -
      advance;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          'Live Driver Tracking',
        ),
      ),
      body:
          Column(
        children: [

          Expanded(
            flex: 6,
            child:
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
                initialZoom:
                    8,
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
                        width:
                            70,
                        height:
                            70,
                        child:
                            Container(
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape
                                    .circle,
                            color: Colors
                                .blue
                                .withValues(
                              alpha:
                                  0.2,
                            ),
                          ),
                          child:
                              const Icon(
                            Icons
                                .local_taxi,
                            size:
                                42,
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
            flex: 3,
            child:
                Card(
              margin:
                  const EdgeInsets
                      .all(10),
              child:
                  Padding(
                padding:
                    const EdgeInsets
                        .all(16),
                child:
                    Column(
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
                          fontSize:
                              18,
                          fontWeight:
                              FontWeight
                                  .bold,
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
                        const Icon(
                          Icons.circle,
                          size: 12,
                          color:
                              Colors.green,
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
                        fontSize:
                            22,
                        fontWeight:
                            FontWeight
                                .bold,
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
                        fontSize:
                            19,
                        fontWeight:
                            FontWeight
                                .bold,
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

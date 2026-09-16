
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const String backendUrl = 'https://hr-ride.onrender.com';

// Change this to the real admin phone number before production.
const String adminPhone = '+16505551234';

const double acRate = 20.0;
const double nonAcRate = 17.0;
const double holdingRate = 100.0;
const double advancePercent = 0.50;
const double cashbackPercent = 0.02;

const String vehicleName = 'Maruti Ertiga';
const List<String> availableVehicles = <String>[
  'Maruti Ertiga',
  'Maruti Omni',
];
const double vehicleMileage = 22.0;
const String serviceRegion = 'West Bengal';

final FirebaseFirestore db = FirebaseFirestore.instance;
final FirebaseAuth auth = FirebaseAuth.instance;
final GoogleSignIn googleSignIn = GoogleSignIn.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  try {
    await googleSignIn.initialize(
      serverClientId:
          '383829745014-1m58ttp9dj4dqike8ot15uva7vnbajua.apps.googleusercontent.com',
    );
  } catch (_) {
    // Google sign-in initialization can be skipped on platforms where it
    // has already been initialized by the plugin.
  }

  runApp(const HRRideApp());
}

class HRRideApp extends StatelessWidget {
  const HRRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HR RIDE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6F9FF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1769FF),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0D1B35),
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E9F5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E9F5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF1769FF),
              width: 1.5,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE8EEF8)),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  final otpController = TextEditingController();

  bool loading = false;
  bool otpSent = false;
  String? verificationId;

  @override
  void dispose() {
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }

  String normalizedPhone() {
    final raw = phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (raw.length == 10) return '+91$raw';
    if (raw.startsWith('91') && raw.length == 12) return '+$raw';
    if (raw.startsWith('+')) return raw;
    return '+$raw';
  }

  Future<void> sendOtp() async {
    final phone = normalizedPhone();

    if (phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      snack(context, 'Enter a valid 10-digit phone number.');
      return;
    }

    setState(() => loading = true);

    await auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (credential) async {
        try {
          await auth.signInWithCredential(credential);
        } catch (e) {
          if (mounted) snack(context, 'Auto verification failed: $e');
        }
      },
      verificationFailed: (e) {
        if (mounted) {
          setState(() => loading = false);
          snack(context, e.message ?? 'Phone verification failed.');
        }
      },
      codeSent: (id, _) {
        if (!mounted) return;
        setState(() {
          verificationId = id;
          otpSent = true;
          loading = false;
        });
        snack(context, 'OTP sent.');
      },
      codeAutoRetrievalTimeout: (id) {
        verificationId = id;
      },
    );
  }

  Future<void> verifyOtp() async {
    if (verificationId == null || otpController.text.trim().length < 6) {
      snack(context, 'Enter the OTP.');
      return;
    }

    setState(() => loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otpController.text.trim(),
      );
      await auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      snack(context, e.message ?? 'Invalid OTP.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> googleLogin() async {
    setState(() => loading = true);
    try {
      final account = await googleSignIn.authenticate();
      final idToken = account.authentication.idToken;

      if (idToken == null) {
        throw Exception('Google ID token was not returned.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await auth.signInWithCredential(credential);
    } catch (e) {
      if (mounted) snack(context, 'Google login failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  const Icon(Icons.local_taxi, size: 76),
                  const SizedBox(height: 16),
                  const Text(
                    'HR RIDE',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Premium Cab Booking'),
                  const SizedBox(height: 32),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      prefixText: '+91 ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (otpSent)
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'OTP',
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading
                          ? null
                          : otpSent
                              ? verifyOtp
                              : sendOtp,
                      child: Text(
                        loading
                            ? 'Please wait...'
                            : otpSent
                                ? 'VERIFY OTP'
                                : 'SEND OTP',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: loading ? null : googleLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('Continue with Google'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  bool get isAdmin => auth.currentUser?.phoneNumber == adminPhone;

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HR RIDE',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .4),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await auth.signOut();
              try {
                await googleSignIn.signOut();
              } catch (_) {}
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _hero(user),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniFeature(
                  Icons.verified_rounded,
                  'Verified',
                  'Safe rides',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniFeature(
                  Icons.location_on_rounded,
                  'All Locations',
                  serviceRegion,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _walletBanner(context),
          const SizedBox(height: 12),
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF10203D),
            ),
          ),
          const SizedBox(height: 6),
          HomeTile(
            icon: Icons.local_taxi_rounded,
            title: 'Book HR RIDE',
            subtitle: 'Maruti Ertiga • Maruti Omni',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookingPage()),
            ),
          ),
          HomeTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'My Wallet',
            subtitle: '2% cashback after completed trips',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WalletPage()),
            ),
          ),
          HomeTile(
            icon: Icons.receipt_long_rounded,
            title: 'My Bookings',
            subtitle: 'Booking, payment & trip status',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyBookingsPage()),
            ),
          ),
          if (isAdmin)
            HomeTile(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Admin Panel',
              subtitle: 'Accept or reject bookings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPanel()),
              ),
            ),
          if (isAdmin)
            HomeTile(
              icon: Icons.directions_car_filled_rounded,
              title: 'Driver Mode',
              subtitle: 'Start trip & share live location',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DriverModePage()),
              ),
            ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Safe Rides  •  Wallet Rewards  •  24/7 Support',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF71809A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(User? user) {
    final name = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : user?.phoneNumber ?? 'HR RIDE Customer';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1769FF), Color(0xFF49A4FF)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331769FF),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WELCOME TO',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'HR RIDE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Hi, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _miniFeature(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7EDF7)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1769FF)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14233F),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF78869D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletBanner(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WalletPage()),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3FF),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD7E8FF)),
        ),
        child: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF1769FF),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallet & Cashback',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10203D),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Get 2% cashback after your completed trip.',
                    style: TextStyle(color: Color(0xFF65748B)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Color(0xFF1769FF)),
          ],
        ),
      ),
    );
  }
}

class HomeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const HomeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
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
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final pickupController = TextEditingController();
  final dropController = TextEditingController();

  String vehicleType = 'AC';
  String selectedVehicle = vehicleName;
  Map<String, dynamic> selectedVehicleData = const {};
  bool upAndDown = false;
  double? routeDistanceKm;
  DateTime travelDate = DateTime.now().add(const Duration(days: 1));
  int holdingHours = 0;

  double? distanceKm;
  int? durationMinutes;
  bool calculatingRoute = false;
  bool paying = false;
  double walletBalance = 0.0;
  bool useWallet = true;

  final CFPaymentGatewayService cashfree = CFPaymentGatewayService();

  @override
  void initState() {
    super.initState();

    final user = auth.currentUser;
    nameController.text = user?.displayName ?? '';
    phoneController.text = user?.phoneNumber?.replaceFirst('+91', '') ?? '';
    emailController.text = user?.email ?? '';
    _loadWallet();

    cashfree.setCallback(
      _onCashfreeVerify,
      _onCashfreeError,
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    pickupController.dispose();
    dropController.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    final user = auth.currentUser;
    if (user == null) return;
    try {
      final snap = await db.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          walletBalance = NumberUtil.toDouble(snap.data()?['walletBalance']) ?? 0;
        });
      }
    } catch (_) {}
  }

  double get walletUseLimit => totalAmount * 0.01;
  double get walletUsed => useWallet ? min(walletBalance, walletUseLimit) : 0;
  double get payableTotal => max(0, totalAmount - walletUsed);

  double get rate {
    final dynamicRate = vehicleType == 'AC'
        ? NumberUtil.toDouble(selectedVehicleData['acRate'])
        : NumberUtil.toDouble(selectedVehicleData['nonAcRate']);
    return dynamicRate ?? (vehicleType == 'AC' ? acRate : nonAcRate);
  }

  double get selectedMileage =>
      NumberUtil.toDouble(selectedVehicleData['mileage']) ?? vehicleMileage;

  double get distanceFare => (distanceKm ?? 0) * rate;

  double get holdingFare => holdingHours * holdingRate;


  double get totalAmount =>
      distanceFare + holdingFare;

  double get advanceAmount => payableTotal * advancePercent;

  double get balanceAmount => max(0, payableTotal - advanceAmount);

  Future<void> calculateRoute() async {
    final pickup = pickupController.text.trim();
    final drop = dropController.text.trim();

    if (pickup.isEmpty || drop.isEmpty) {
      snack(context, 'Enter pickup and drop location.');
      return;
    }

    setState(() => calculatingRoute = true);

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/route-distance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pickup': pickup,
          'drop': drop,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['success'] != true) {
        throw Exception(data['error'] ?? 'Route calculation failed.');
      }

      final km = NumberUtil.toDouble(data['distanceKm']);
      final minutes = NumberUtil.toInt(data['durationMinutes']);

      if (km == null || km <= 0) {
        throw Exception('Invalid distance returned by server.');
      }

      final chargeableKm = km * 2;
      setState(() {
        routeDistanceKm = km;
        distanceKm = chargeableKm;
        durationMinutes = minutes == null ? null : minutes * 2;
      });

      snack(
        context,
        'Route: ${km.toStringAsFixed(1)} km • Chargeable: ${chargeableKm.toStringAsFixed(1)} km'
        '${minutes != null ? ' • ${minutes * 2} min approx.' : ''}',
      );
    } catch (e) {
      snack(context, 'Route error: $e');
    } finally {
      if (mounted) setState(() => calculatingRoute = false);
    }
  }

  Future<void> chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: travelDate,
    );

    if (picked != null) {
      setState(() {
        travelDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          travelDate.hour,
          travelDate.minute,
        );
      });
    }
  }

  Future<String> createBooking() async {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('Please login again.');
    }

    if (nameController.text.trim().isEmpty) {
      throw Exception('Enter customer name.');
    }

    if (phoneController.text.replaceAll(RegExp(r'\D'), '').length < 10) {
      throw Exception('Enter a valid phone number.');
    }

    if (distanceKm == null || distanceKm! <= 0) {
      throw Exception('Calculate route distance first.');
    }

    if (totalAmount < 1) {
      throw Exception('Booking amount must be at least ₹1.');
    }

    final bookingRef = db.collection('bookings').doc();

    await bookingRef.set({
      'userId': user.uid,
      'userName': nameController.text.trim(),
      'userPhone': normalizeCustomerPhone(phoneController.text),
      'userEmail': emailController.text.trim(),
      'pickup': pickupController.text.trim(),
      'drop': dropController.text.trim(),
      'vehicle': selectedVehicle,
      'mileage': selectedMileage,
      'region': serviceRegion,
      'vehicleType': vehicleType,
      'vehicleName': selectedVehicle,
      'travelDate': Timestamp.fromDate(travelDate),
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      'chargeableKm': distanceKm,
      'ratePerKm': rate,
      'tripType': upAndDown ? 'Up & Down' : 'One Way',
      'routeDistanceKm': routeDistanceKm,
      'holdingHours': holdingHours,
      'holdingRate': holdingRate,
      'holdingCharge': holdingFare,
      'distanceFare': distanceFare,
      'holdingFare': holdingFare,
      'totalAmount': totalAmount,
      'walletUsed': walletUsed,
      'payableTotal': payableTotal,
      'advancePercent': advancePercent * 100,
      'advanceNonRefundable': true,
      'advanceAmount': advanceAmount,
      'balanceAmount': balanceAmount,
      'paymentStatus': 'Pending',
      'paymentId': '',
      'orderId': '',
      'status': 'Payment Pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return bookingRef.id;
  }

  Future<void> startPayment() async {
    if (paying) return;

    setState(() => paying = true);

    String? bookingId;

    try {
      bookingId = await createBooking();

      final user = auth.currentUser!;
      final response = await http.post(
        Uri.parse('$backendUrl/api/create-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bookingId': bookingId,
          'amount': double.parse(advanceAmount.toStringAsFixed(2)),
          'customerId': user.uid,
          'customerName': nameController.text.trim(),
          'customerEmail': emailController.text.trim(),
          'customerPhone': normalizeCustomerPhone(phoneController.text),
          'orderNote': 'HR RIDE Booking Advance - $bookingId',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['success'] != true) {
        throw Exception(data['error'] ?? 'Unable to create payment order.');
      }

      final orderId = data['orderId']?.toString();
      final paymentSessionId =
          data['paymentSessionId']?.toString();

      if (orderId == null ||
          orderId.isEmpty ||
          paymentSessionId == null ||
          paymentSessionId.isEmpty) {
        throw Exception('Cashfree payment session was not returned.');
      }

      await db.collection('bookings').doc(bookingId).update({
        'orderId': orderId,
        'paymentSessionId': paymentSessionId,
        'paymentStatus': 'Created',
      });

      final session = CFSessionBuilder()
          .setEnvironment(CFEnvironment.PRODUCTION)
          .setOrderId(orderId)
          .setPaymentSessionId(paymentSessionId)
          .build();

      // Use Cashfree Hosted Web Checkout. Drop Checkout is deprecated in
      // flutter_cashfree_pg_sdk 2.4.x.
      final payment = CFWebCheckoutPaymentBuilder()
          .setSession(session)
          .build();

      cashfree.doPayment(payment);
    } catch (e) {
      if (bookingId != null) {
        try {
          await db.collection('bookings').doc(bookingId).update({
            'paymentStatus': 'Failed',
            'paymentError': e.toString(),
          });
        } catch (_) {}
      }

      if (mounted) {
        setState(() => paying = false);
        snack(context, 'Payment setup failed: $e');
      }
    }
  }

  Future<void> _onCashfreeVerify(String orderId) async {
    if (!mounted) return;

    try {
      final response = await http.get(
        Uri.parse(
          '$backendUrl/api/order-status/${Uri.encodeComponent(orderId)}',
        ),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['success'] != true) {
        throw Exception(data['error'] ?? 'Unable to verify payment.');
      }

      final status =
          (data['orderStatus'] ?? 'UNKNOWN').toString().toUpperCase();

      final query = await db
          .collection('bookings')
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('Booking for payment order was not found.');
      }

      final bookingDoc = query.docs.first;

      if (status == 'PAID') {
        final bookingData = bookingDoc.data();
        if (bookingData['walletDeducted'] != true) {
          final walletUsedNow = NumberUtil.toDouble(bookingData['walletUsed']) ?? 0;
          if (walletUsedNow > 0) {
            final uid = bookingData['userId']?.toString();
            if (uid != null) {
              final walletRef = db.collection('users').doc(uid);
              await db.runTransaction((tx) async {
                final ws = await tx.get(walletRef);
                final current = NumberUtil.toDouble(ws.data()?['walletBalance']) ?? 0;
                final deduction = min(current, walletUsedNow);
                tx.set(walletRef, {
                  'walletBalance': max(0, current - deduction),
                  'walletUpdatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                tx.set(walletRef.collection('walletTransactions').doc(), {
                  'type': 'booking_payment',
                  'bookingId': bookingDoc.id,
                  'amount': deduction,
                  'description': 'Used for Booking ${bookingDoc.id}',
                  'createdAt': FieldValue.serverTimestamp(),
                });
              });
            }
          }
        }
        await bookingDoc.reference.update({
          'walletDeducted': true,
          'paymentStatus': 'Paid',
          'status': 'Confirmed',
          'paymentVerifiedAt': FieldValue.serverTimestamp(),
          'cashfreeOrderStatus': status,
        });

        if (!mounted) return;
        setState(() => paying = false);

        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Payment Successful'),
            content: Text(
              '₹${advanceAmount.toStringAsFixed(2)} advance payment received.\n\n'
              'Booking ID: ${bookingDoc.id}\n'
              'Order ID: $orderId',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('DONE'),
              ),
            ],
          ),
        );
      } else {
        await bookingDoc.reference.update({
          'paymentStatus': status,
          'cashfreeOrderStatus': status,
        });

        if (!mounted) return;
        setState(() => paying = false);
        snack(context, 'Payment status: $status');
      }
    } catch (e) {
      if (mounted) {
        setState(() => paying = false);
        snack(context, 'Payment verification failed: $e');
      }
    }
  }

  void _onCashfreeError(CFErrorResponse error, String orderId) {
    final message = error.getMessage();

    if (mounted) {
      setState(() => paying = false);
      snack(
        context,
        'Cashfree payment error: $message\nOrder: $orderId',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book HR RIDE')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const InfoCard(),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Customer Name',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email (optional)',
              prefixIcon: Icon(Icons.email),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: pickupController,
            decoration: const InputDecoration(
              labelText: 'Pickup Location',
              prefixIcon: Icon(Icons.my_location),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: dropController,
            decoration: const InputDecoration(
              labelText: 'Drop Location',
              prefixIcon: Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: calculatingRoute ? null : calculateRoute,
            icon: calculatingRoute
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.route),
            label: Text(
              calculatingRoute ? 'CALCULATING...' : 'CALCULATE DISTANCE',
            ),
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('vehicles').where('active', isEqualTo: true).snapshots(),
            builder: (context, snapshot) {
              final dynamicVehicles = <Map<String, dynamic>>[];
              if (snapshot.hasData) {
                for (final doc in snapshot.data!.docs) {
                  final v = doc.data();
                  v['id'] = doc.id;
                  dynamicVehicles.add(v);
                }
              }
              if (dynamicVehicles.isEmpty) {
                dynamicVehicles.addAll([
                  {
                    'id': 'ertiga_default',
                    'name': 'Maruti Ertiga',
                    'seats': 7,
                    'mileage': 22,
                    'acRate': 20,
                    'nonAcRate': 17,
                    'active': true,
                  },
                  {
                    'id': 'omni_default',
                    'name': 'Maruti Omni',
                    'seats': 8,
                    'mileage': 16,
                    'acRate': 20,
                    'nonAcRate': 17,
                    'active': true,
                  },
                ]);
              }
              final names = dynamicVehicles
                  .map((v) => (v['name'] ?? '').toString())
                  .where((n) => n.isNotEmpty)
                  .toList();
              final current = names.contains(selectedVehicle) ? selectedVehicle : names.first;
              final currentData = dynamicVehicles.firstWhere(
                (v) => (v['name'] ?? '').toString() == current,
                orElse: () => dynamicVehicles.first,
              );
              return DropdownButtonFormField<String>(
                value: current,
                decoration: const InputDecoration(
                  labelText: 'Vehicle',
                  prefixIcon: Icon(Icons.directions_car),
                ),
                items: dynamicVehicles.map((v) {
                  final name = (v['name'] ?? 'Vehicle').toString();
                  final seats = (v['seats'] ?? '').toString();
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Text(seats.isEmpty ? name : '$name • $seats Seater'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  final data = dynamicVehicles.firstWhere(
                    (v) => (v['name'] ?? '').toString() == value,
                    orElse: () => currentData,
                  );
                  setState(() {
                    selectedVehicle = value;
                    selectedVehicleData = Map<String, dynamic>.from(data);
                  });
                },
              );
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: vehicleType,
            decoration: const InputDecoration(
              labelText: 'AC / Non-AC',
              prefixIcon: Icon(Icons.ac_unit),
            ),
            items: [
              DropdownMenuItem(value: 'AC', child: Text('AC • ₹${NumberUtil.toDouble(selectedVehicleData['acRate'])?.toStringAsFixed(0) ?? acRate.toStringAsFixed(0)}/km')),
              DropdownMenuItem(value: 'Non-AC', child: Text('Non-AC • ₹${NumberUtil.toDouble(selectedVehicleData['nonAcRate'])?.toStringAsFixed(0) ?? nonAcRate.toStringAsFixed(0)}/km')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => vehicleType = value);
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: const Color(0xFFEAF3FF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.route_rounded),
            title: Text(upAndDown ? 'Up & Down' : 'One Way'),
            subtitle: Text(upAndDown
                ? 'Route distance × 2 • Holding ₹100/hour'
                : 'Route distance × 2 • No holding charge'),
            trailing: Switch(
              value: upAndDown,
              onChanged: (v) => setState(() => upAndDown = v),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: holdingHours,
            decoration: const InputDecoration(
              labelText: 'Holding Hours',
              prefixIcon: Icon(Icons.schedule),
            ),
            items: List.generate(25, (i) => DropdownMenuItem<int>(
              value: i,
              child: Text(i == 0 ? 'No Holding' : '$i hour${i == 1 ? '' : 's'} • ₹${(i * holdingRate).toStringAsFixed(0)}'),
            )),
            onChanged: (v) => setState(() => holdingHours = v ?? 0),
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: const Color(0xFFF4F7FC),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.calendar_month),
            title: const Text('Travel Date'),
            subtitle: Text(formatDate(travelDate)),
            trailing: TextButton(onPressed: chooseDate, child: const Text('CHANGE')),
          ),
          const SizedBox(height: 14),
          Card(
            child: SwitchListTile(
              value: useWallet && walletBalance > 0,
              onChanged: walletBalance > 0
                  ? (v) => setState(() => useWallet = v)
                  : null,
              secondary: const Icon(Icons.account_balance_wallet),
              title: const Text('Use Wallet Balance'),
              subtitle: Text(
                walletBalance > 0
                    ? 'Available ${money(walletBalance)} • Use up to ${money(walletUseLimit)}'
                    : 'No wallet balance available',
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (routeDistanceKm != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                upAndDown
                    ? 'Up & Down: ${routeDistanceKm!.toStringAsFixed(1)} km × 2 + ₹1,000 holding'
                    : 'One Way: ${routeDistanceKm!.toStringAsFixed(1)} km × 2',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          FareCard(
            distanceKm: distanceKm,
            rate: rate,
            distanceFare: distanceFare,
            holdingFare: holdingFare,
            totalAmount: totalAmount,
            advanceAmount: advanceAmount,
            balanceAmount: balanceAmount,
          ),
          const SizedBox(height: 8),
          if (walletUsed > 0)
            Text(
              'Wallet used: -${money(walletUsed)} • Payable: ${money(payableTotal)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: paying || distanceKm == null ? null : startPayment,
              icon: paying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.payment),
              label: Text(
                paying
                    ? 'PROCESSING...'
                    : 'PAY ₹${advanceAmount.toStringAsFixed(0)} ADVANCE (50%)',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Booking advance is 50% and non-refundable. Payment is processed securely by Cashfree.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.directions_car, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    vehicleName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('22 km/l • $serviceRegion'),
                  const SizedBox(height: 4),
                  Text('AC ₹$acRate/km • Non-AC ₹$nonAcRate/km'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FareCard extends StatelessWidget {
  final double? distanceKm;
  final double rate;
  final double distanceFare;
  final double holdingFare;
  final double totalAmount;
  final double advanceAmount;
  final double balanceAmount;

  const FareCard({
    super.key,
    required this.distanceKm,
    required this.rate,
    required this.distanceFare,
    required this.holdingFare,
    required this.totalAmount,
    required this.advanceAmount,
    required this.balanceAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'FARE SUMMARY',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            fareRow(
              'Distance',
              distanceKm == null
                  ? '--'
                  : '${distanceKm!.toStringAsFixed(1)} km × ₹${rate.toStringAsFixed(0)}',
            ),
            fareRow('Distance Fare', money(distanceFare)),
            fareRow('Holding Fare', money(holdingFare)),
            const Divider(),
            fareRow('TOTAL', money(totalAmount), bold: true),
            fareRow(
              '50% ADVANCE',
              money(advanceAmount),
              bold: true,
            ),
            fareRow('Balance', money(balanceAmount)),
          ],
        ),
      ),
    );
  }

  Widget fareRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Please login again.')));
    final walletRef = db.collection('users').doc(uid);
    return Scaffold(
      appBar: AppBar(title: const Text('My Wallet')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: walletRef.snapshots(),
        builder: (context, snap) {
          final balance = NumberUtil.toDouble(snap.data?.data()?['walletBalance']) ?? 0;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.account_balance_wallet, size: 34),
                    const SizedBox(height: 10),
                    const Text('Wallet Balance'),
                    Text(money(balance), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.card_giftcard),
                  title: const Text('Get 5% Cashback'),
                  subtitle: const Text('Cashback is credited after your trip is completed.'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.savings),
                  title: const Text('Use Wallet on Next Booking'),
                  subtitle: const Text('Wallet balance can reduce your next booking amount.'),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Wallet Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: walletRef.collection('walletTransactions').orderBy('createdAt', descending: true).limit(30).snapshots(),
                builder: (context, txSnap) {
                  if (!txSnap.hasData || txSnap.data!.docs.isEmpty) {
                    return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No wallet transactions yet.')));
                  }
                  return Column(children: txSnap.data!.docs.map((d) {
                    final x = d.data();
                    final amount = NumberUtil.toDouble(x['amount']) ?? 0;
                    final type = (x['type'] ?? '').toString();
                    final credit = type == 'cashback' || type == 'add_money';
                    return Card(child: ListTile(
                      leading: Icon(credit ? Icons.arrow_downward : Icons.arrow_upward),
                      title: Text((x['description'] ?? 'Wallet transaction').toString()),
                      trailing: Text('${credit ? '+' : '-'}${money(amount)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ));
                  }).toList());
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class MyBookingsPage extends StatelessWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please login again.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('bookings')
            .where('userId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...snapshot.data!.docs];
          docs.sort((a, b) {
            final at = (a.data()['createdAt'] as Timestamp?)
                    ?.millisecondsSinceEpoch ??
                0;
            final bt = (b.data()['createdAt'] as Timestamp?)
                    ?.millisecondsSinceEpoch ??
                0;
            return bt.compareTo(at);
          });

          if (docs.isEmpty) {
            return const Center(child: Text('No bookings yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              return BookingCard(
                doc: docs[i],
                isAdmin: false,
              );
            },
          );
        },
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isAdmin;

  const BookingCard({
    super.key,
    required this.doc,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final b = doc.data();
    final status = (b['status'] ?? 'Pending').toString();
    final paymentStatus = (b['paymentStatus'] ?? 'Pending').toString();
    final total = NumberUtil.toDouble(b['totalAmount']) ?? 0;
    final advance = NumberUtil.toDouble(b['advanceAmount']) ?? 0;
    final distance = NumberUtil.toDouble(b['distanceKm']) ?? 0;

    final canTrack =
        status == 'Confirmed' || status == 'Trip Started';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Booking ${doc.id.substring(0, min(8, doc.id.length))}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                StatusChip(text: status),
              ],
            ),
            const SizedBox(height: 10),
            infoLine(Icons.person, b['userName']?.toString() ?? ''),
            infoLine(Icons.phone, b['userPhone']?.toString() ?? ''),
            infoLine(
              Icons.my_location,
              b['pickup']?.toString() ?? '',
            ),
            infoLine(
              Icons.location_on,
              b['drop']?.toString() ?? '',
            ),
            infoLine(
              Icons.route,
              '${distance.toStringAsFixed(1)} km',
            ),
            infoLine(
              Icons.payments,
              'Total ${money(total)} • Advance ${money(advance)}',
            ),
            infoLine(
              Icons.verified,
              'Payment: $paymentStatus',
            ),
            if (b['orderId']?.toString().isNotEmpty == true)
              infoLine(Icons.receipt, 'Order: ${b['orderId']}'),
            if ((b['driverName'] ?? '').toString().isNotEmpty) ...[
              const Divider(height: 24),
              infoLine(Icons.person_pin_circle, 'Driver: ${b['driverName']}'),
              infoLine(Icons.phone, 'Driver Phone: ${b['driverPhone'] ?? ''}'),
              if ((b['vehicleNumber'] ?? '').toString().isNotEmpty)
                infoLine(Icons.confirmation_number, 'Vehicle No: ${b['vehicleNumber']}'),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final phone = (b['driverPhone'] ?? '').toString().trim();
                    if (phone.isEmpty) { snack(context, 'Driver phone not available.'); return; }
                    final uri = Uri(scheme: 'tel', path: phone);
                    if (!await launchUrl(uri)) snack(context, 'Could not open phone dialer.');
                  },
                  icon: const Icon(Icons.call),
                  label: const Text('CALL DRIVER'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (canTrack)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerTrackingPage(
                          bookingId: doc.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text('TRACK DRIVER'),
                ),
              ),
            final balance = NumberUtil.toDouble(b['balanceAmount']) ?? 0;
            final balanceStatus = (b['balancePaymentStatus'] ?? 'Pending').toString();
            if (paymentStatus == 'Paid' && balance > 0 && balanceStatus != 'Paid') ...[
              const SizedBox(height: 10),
              Text('Balance: ${money(balance)} • ${balanceStatus == 'Cash Pending' ? 'Cash Pending' : 'Pending'}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await db.collection('bookings').doc(doc.id).update({
                        'balancePaymentMethod': 'Cash',
                        'balancePaymentStatus': 'Cash Pending',
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) snack(context, 'Cash payment marked pending. Driver/Admin will confirm.');
                    } catch (e) { if (context.mounted) snack(context, 'Update failed: $e'); }
                  },
                  icon: const Icon(Icons.money), label: const Text('CASH'),
                )),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => BalancePaymentPage(bookingId: doc.id, balanceAmount: balance)));
                  },
                  icon: const Icon(Icons.credit_card), label: const Text('ONLINE'),
                )),
              ]),
            ],
            if (status == 'Trip Started')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Trip is currently running.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BalancePaymentPage extends StatefulWidget {
  final String bookingId;
  final double balanceAmount;
  const BalancePaymentPage({super.key, required this.bookingId, required this.balanceAmount});

  @override
  State<BalancePaymentPage> createState() => _BalancePaymentPageState();
}

class _BalancePaymentPageState extends State<BalancePaymentPage> {
  final CFPaymentGatewayService cashfree = CFPaymentGatewayService();
  bool paying = false;

  @override
  void initState() {
    super.initState();
    cashfree.setCallback(_verify, _error);
  }

  Future<void> _pay() async {
    if (paying) return;
    setState(() => paying = true);
    try {
      final user = auth.currentUser;
      if (user == null) throw Exception('Please login again.');
      final response = await http.post(
        Uri.parse('$backendUrl/api/create-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bookingId': widget.bookingId,
          'paymentType': 'balance',
          'amount': widget.balanceAmount,
          'customerId': user.uid,
          'customerName': user.displayName ?? 'HR RIDE Customer',
          'customerEmail': user.email ?? '',
          'customerPhone': user.phoneNumber?.replaceFirst('+91', '') ?? '',
          'orderNote': 'HR RIDE Balance Payment',
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
        throw Exception(data['error'] ?? 'Could not create balance order.');
      }
      final orderId = data['orderId']?.toString();
      final sessionId = data['paymentSessionId']?.toString();
      if (orderId == null || sessionId == null || orderId.isEmpty || sessionId.isEmpty) {
        throw Exception('Cashfree payment session missing.');
      }
      await db.collection('bookings').doc(widget.bookingId).update({
        'balanceOrderId': orderId,
        'balancePaymentMethod': 'Online',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final session = CFSessionBuilder()
          .setEnvironment(CFEnvironment.PRODUCTION)
          .setOrderId(orderId)
          .setPaymentSessionId(sessionId)
          .build();
      final payment = CFWebCheckoutPaymentBuilder().setSession(session).build();
      cashfree.doPayment(payment);
    } catch (e) {
      if (mounted) { setState(() => paying = false); snack(context, 'Payment error: $e'); }
    }
  }

  Future<void> _verify(String orderId) async {
    try {
      final response = await http.get(Uri.parse('$backendUrl/api/order-status/$orderId'));
      final data = jsonDecode(response.body);
      final status = (data['orderStatus'] ?? '').toString().toUpperCase();
      if (status == 'PAID' || status == 'SUCCESS') {
        await db.collection('bookings').doc(widget.bookingId).update({
          'balancePaymentStatus': 'Paid',
          'balancePaidAt': FieldValue.serverTimestamp(),
          'balanceCashfreeOrderStatus': status,
          'balanceOrderId': orderId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        setState(() => paying = false);
        await showDialog<void>(context: context, builder: (_) => AlertDialog(
          title: const Text('Balance Paid ✅'),
          content: Text('₹${widget.balanceAmount.toStringAsFixed(2)} balance payment received.'),
          actions: [FilledButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('DONE'))],
        ));
      } else {
        if (mounted) { setState(() => paying = false); snack(context, 'Payment status: $status'); }
      }
    } catch (e) {
      if (mounted) { setState(() => paying = false); snack(context, 'Verification failed: $e'); }
    }
  }

  void _error(CFErrorResponse error, String orderId) {
    if (mounted) { setState(() => paying = false); snack(context, 'Cashfree error: ${error.getMessage()}'); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pay Balance')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          const Text('Remaining Balance', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text(money(widget.balanceAmount), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
        ]))),
        const SizedBox(height: 20),
        const Text('Pay securely online using Cashfree.'),
        const Spacer(),
        SizedBox(width: double.infinity, height: 54, child: FilledButton.icon(
          onPressed: paying ? null : _pay,
          icon: paying ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.payment),
          label: Text(paying ? 'PROCESSING...' : 'PAY ${money(widget.balanceAmount)} ONLINE'),
        )),
      ]),
    ),
  );
}

class VehicleAdminPage extends StatefulWidget {
  const VehicleAdminPage({super.key});

  @override
  State<VehicleAdminPage> createState() => _VehicleAdminPageState();
}

class _VehicleAdminPageState extends State<VehicleAdminPage> {
  final name = TextEditingController();
  final seats = TextEditingController(text: '7');
  final mileage = TextEditingController(text: '22');
  final ac = TextEditingController(text: '20');
  final nonAc = TextEditingController(text: '17');
  final number = TextEditingController();
  final imageUrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [name, seats, mileage, ac, nonAc, number, imageUrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> addVehicle() async {
    final vehicleNameText = name.text.trim();
    if (vehicleNameText.isEmpty) {
      snack(context, 'Enter car name.');
      return;
    }
    final doc = db.collection('vehicles').doc();
    await doc.set({
      'name': vehicleNameText,
      'seats': int.tryParse(seats.text.trim()) ?? 0,
      'mileage': double.tryParse(mileage.text.trim()) ?? 0,
      'acRate': double.tryParse(ac.text.trim()) ?? acRate,
      'nonAcRate': double.tryParse(nonAc.text.trim()) ?? nonAcRate,
      'vehicleNumber': number.text.trim(),
      'imageUrl': imageUrl.text.trim(),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    name.clear(); number.clear(); imageUrl.clear();
    if (mounted) snack(context, 'Vehicle added successfully.');
  }

  Future<void> editVehicle(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data() ?? {};
    final n = TextEditingController(text: '${d['name'] ?? ''}');
    final s = TextEditingController(text: '${d['seats'] ?? 7}');
    final m = TextEditingController(text: '${d['mileage'] ?? 22}');
    final a = TextEditingController(text: '${d['acRate'] ?? 20}');
    final na = TextEditingController(text: '${d['nonAcRate'] ?? 17}');
    final num = TextEditingController(text: '${d['vehicleNumber'] ?? ''}');
    final img = TextEditingController(text: '${d['imageUrl'] ?? ''}');
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('Edit Vehicle'),
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: n, decoration: const InputDecoration(labelText: 'Car Name')),
        TextField(controller: s, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seats')),
        TextField(controller: m, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Mileage')),
        TextField(controller: a, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'AC Rate / km')),
        TextField(controller: na, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Non-AC Rate / km')),
        TextField(controller: num, decoration: const InputDecoration(labelText: 'Vehicle Number')),
        TextField(controller: img, decoration: const InputDecoration(labelText: 'Image URL (optional)')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        FilledButton(onPressed: () async {
          await doc.reference.update({
            'name': n.text.trim(), 'seats': int.tryParse(s.text) ?? 0,
            'mileage': double.tryParse(m.text) ?? 0,
            'acRate': double.tryParse(a.text) ?? acRate,
            'nonAcRate': double.tryParse(na.text) ?? nonAcRate,
            'vehicleNumber': num.text.trim(), 'imageUrl': img.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          if (context.mounted) Navigator.pop(context);
        }, child: const Text('SAVE')),
      ],
    ));
    for (final c in [n, s, m, a, na, num, img]) { c.dispose(); }
  }

  Future<void> toggleVehicle(DocumentSnapshot<Map<String, dynamic>> doc, bool active) async {
    await doc.reference.update({'active': active, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteVehicle(DocumentSnapshot<Map<String, dynamic>> doc) async {
    await doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Vehicles')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add Any Car', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Car Name', prefixIcon: Icon(Icons.directions_car))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: seats, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seats'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: mileage, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Mileage'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: ac, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'AC ₹/km'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: nonAc, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Non-AC ₹/km'))),
          ]),
          const SizedBox(height: 8),
          TextField(controller: number, decoration: const InputDecoration(labelText: 'Vehicle Number')),
          const SizedBox(height: 8),
          TextField(controller: imageUrl, decoration: const InputDecoration(labelText: 'Car Image URL (optional)')),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: addVehicle, icon: const Icon(Icons.add), label: const Text('ADD VEHICLE'))),
        ]))),
        const SizedBox(height: 8),
        const Text('Your Vehicles', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('vehicles').orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(16), child: Text('Error: ${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('No custom vehicles yet.'));
            return Column(children: docs.map((doc) {
              final d = doc.data();
              final active = d['active'] == true;
              return Card(child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.directions_car)),
                title: Text('${d['name'] ?? 'Vehicle'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${d['seats'] ?? '-'} seats • AC ₹${d['acRate'] ?? '-'} • Non-AC ₹${d['nonAcRate'] ?? '-'}\n${d['vehicleNumber'] ?? ''}'),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(onSelected: (v) async {
                  if (v == 'edit') await editVehicle(doc);
                  if (v == 'toggle') await toggleVehicle(doc, !active);
                  if (v == 'delete') await deleteVehicle(doc);
                }, itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'toggle', child: Text(active ? 'Disable' : 'Enable')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ]),
              ));
            }).toList());
          },
        ),
      ]),
    );
  }
}

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  Future<void> updateBooking(
    BuildContext context,
    String bookingId,
    String status,
  ) async {
    try {
      await db.collection('bookings').doc(bookingId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      snack(context, 'Booking $status');
    } catch (e) {
      snack(context, 'Update failed: $e');
    }
  }

  Future<void> assignDriver(BuildContext context, String bookingId, Map<String, dynamic> booking) async {
    final name = TextEditingController(text: '${booking['driverName'] ?? ''}');
    final phone = TextEditingController(text: '${booking['driverPhone'] ?? ''}');
    final vehicleNo = TextEditingController(text: '${booking['vehicleNumber'] ?? ''}');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Assign Driver'),
        content: SingleChildScrollView(child: Column(children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Driver Name', prefixIcon: Icon(Icons.person))),
          const SizedBox(height: 8),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Driver Phone', prefixIcon: Icon(Icons.phone))),
          const SizedBox(height: 8),
          TextField(controller: vehicleNo, decoration: const InputDecoration(labelText: 'Vehicle Number', prefixIcon: Icon(Icons.confirmation_number))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          FilledButton(onPressed: () async {
            if (name.text.trim().isEmpty || phone.text.replaceAll(RegExp(r'\D'), '').length < 10) {
              snack(context, 'Enter driver name and valid phone.'); return;
            }
            await db.collection('bookings').doc(bookingId).update({
              'driverName': name.text.trim(),
              'driverPhone': phone.text.trim(),
              'vehicleNumber': vehicleNo.text.trim(),
              'driverAssignedAt': FieldValue.serverTimestamp(),
              'status': 'Confirmed',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (context.mounted) snack(context, 'Driver assigned successfully.');
          }, child: const Text('ASSIGN')),
        ],
      ),
    );
    name.dispose(); phone.dispose(); vehicleNo.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            tooltip: 'Manage Vehicles',
            icon: const Icon(Icons.directions_car_filled_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VehicleAdminPage()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('bookings').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...snapshot.data!.docs];
          docs.sort((a, b) {
            final at = (a.data()['createdAt'] as Timestamp?)
                    ?.millisecondsSinceEpoch ??
                0;
            final bt = (b.data()['createdAt'] as Timestamp?)
                    ?.millisecondsSinceEpoch ??
                0;
            return bt.compareTo(at);
          });

          if (docs.isEmpty) {
            return const Center(child: Text('No bookings.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final b = docs[i].data();
              final status = (b['status'] ?? 'Pending').toString();
              final payment = (b['paymentStatus'] ?? 'Pending').toString();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Booking ${docs[i].id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          StatusChip(text: status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Customer: ${b['userName'] ?? ''}'),
                      Text('Phone: ${b['userPhone'] ?? ''}'),
                      Text('Pickup: ${b['pickup'] ?? ''}'),
                      Text('Drop: ${b['drop'] ?? ''}'),
                      Text(
                        'Total: ${money(NumberUtil.toDouble(b['totalAmount']) ?? 0)}',
                      ),
                      Text('Payment: $payment'),
                      const SizedBox(height: 10),
                      if (status == 'Payment Pending' ||
                          status == 'Pending')
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: payment == 'Paid'
                                    ? () => updateBooking(
                                          context,
                                          docs[i].id,
                                          'Confirmed',
                                        )
                                    : null,
                                child: const Text('ACCEPT'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => updateBooking(
                                  context,
                                  docs[i].id,
                                  'Rejected',
                                ),
                                child: const Text('REJECT'),
                              ),
                            ),
                          ],
                        ),
                      if (status == 'Confirmed' || status == 'Trip Started') ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => assignDriver(context, docs[i].id, b),
                            icon: const Icon(Icons.person_add_alt_1),
                            label: Text((b['driverName'] ?? '').toString().isEmpty ? 'ASSIGN DRIVER' : 'EDIT DRIVER'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DriverModePage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.directions_car),
                            label: const Text('DRIVER MODE'),
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

class DriverModePage extends StatefulWidget {
  const DriverModePage({super.key});

  @override
  State<DriverModePage> createState() => _DriverModePageState();
}

class _DriverModePageState extends State<DriverModePage> {
  StreamSubscription<Position>? positionSubscription;
  Position? currentPosition;
  bool online = false;
  String? activeBookingId;
  Position? _lastTripPosition;
  double _liveDistanceKm = 0.0;
  bool tripStarting = false;
  bool tripEnding = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        snack(context, 'Please turn on Location/GPS.');
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        snack(context, 'Location permission is required.');
      }
      return false;
    }

    return true;
  }

  Future<void> _loadLocation() async {
    if (!await _ensureLocationPermission()) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() => currentPosition = position);
      }
    } catch (e) {
      if (mounted) snack(context, 'Location error: $e');
    }
  }

  Future<void> toggleOnline() async {
    if (online) {
      await positionSubscription?.cancel();
      positionSubscription = null;

      final uid = auth.currentUser?.uid;
      if (uid != null) {
        await db.collection('driverLocations').doc(uid).set({
          'online': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) setState(() => online = false);
      return;
    }

    if (!await _ensureLocationPermission()) return;

    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await _writeDriverLocation(first, true);

      positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((position) {
        currentPosition = position;
        _writeDriverLocation(position, true);
        if (mounted) setState(() {});
      });

      setState(() {
        online = true;
        currentPosition = first;
      });

      snack(context, 'Driver is online.');
    } catch (e) {
      snack(context, 'Unable to start driver mode: $e');
    }
  }

  Future<void> _writeDriverLocation(
    Position position,
    bool isOnline,
  ) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    await db.collection('driverLocations').doc(uid).set({
      'driverId': uid,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'speed': position.speed,
      'online': isOnline,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (activeBookingId != null) {
      if (_lastTripPosition != null) {
        final meters = Geolocator.distanceBetween(
          _lastTripPosition!.latitude,
          _lastTripPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        // Ignore tiny GPS jitter.
        if (meters >= 5 && meters <= 5000) {
          _liveDistanceKm += meters / 1000.0;
        }
      }

      _lastTripPosition = position;

      final tripSnapshot =
          await db.collection('liveTrips').doc(activeBookingId).get();
      final tripData = tripSnapshot.data() ?? {};
      final tripRate = NumberUtil.toDouble(tripData['ratePerKm']) ?? acRate;
      final liveFare = _liveDistanceKm * tripRate;

      await db.collection('liveTrips').doc(activeBookingId).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'driverId': uid,
        'liveDistanceKm': _liveDistanceKm,
        'liveFare': liveFare,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> startTrip(String bookingId) async {
    if (tripStarting) return;

    setState(() => tripStarting = true);

    try {
      final booking =
          await db.collection('bookings').doc(bookingId).get();

      if (!booking.exists) {
        throw Exception('Booking not found.');
      }

      final b = booking.data()!;
      if (b['status'] != 'Confirmed') {
        throw Exception(
          'Trip can start only after booking is Confirmed.',
        );
      }

      final pos = currentPosition ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );

      final uid = auth.currentUser?.uid;

      await db.collection('liveTrips').doc(bookingId).set({
        'bookingId': bookingId,
        'driverId': uid,
        'customerId': b['userId'],
        'customerName': b['userName'],
        'pickup': b['pickup'],
        'drop': b['drop'],
        'vehicle': b['vehicle'],
        'vehicleType': b['vehicleType'],
        'ratePerKm': b['ratePerKm'],
        'upDownHoldingCharge': 0.0,
        'holdingCharge': 0.0,
        'startLatitude': pos.latitude,
        'startLongitude': pos.longitude,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'liveDistanceKm': 0.0,
        'liveFare': 0.0,
        'status': 'Trip Started',
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await db.collection('bookings').doc(bookingId).update({
        'status': 'Trip Started',
        'driverId': uid,
        'tripStartedAt': FieldValue.serverTimestamp(),
      });

      _liveDistanceKm = 0.0;
      _lastTripPosition = pos;
      setState(() => activeBookingId = bookingId);

      if (!online) {
        await toggleOnline();
      }

      snack(context, 'Trip started.');
    } catch (e) {
      snack(context, 'Start trip failed: $e');
    } finally {
      if (mounted) setState(() => tripStarting = false);
    }
  }

  Future<void> endTrip(String bookingId) async {
    if (tripEnding) return;

    setState(() => tripEnding = true);

    try {
      final tripRef = db.collection('liveTrips').doc(bookingId);
      final trip = await tripRef.get();

      if (!trip.exists) throw Exception('Live trip not found.');

      final t = trip.data()!;
      final liveDistance =
          NumberUtil.toDouble(t['liveDistanceKm']) ?? 0;
      final rate =
          NumberUtil.toDouble(t['ratePerKm']) ?? acRate;
      final finalDistanceFare = liveDistance * rate;
      final finalHoldingFare = 0.0;
      final finalFare = finalDistanceFare + finalHoldingFare;

      await tripRef.update({
        'status': 'Completed',
        'endDistanceKm': liveDistance,
        'holdingHoursFinal': 0.0,
        'distanceFareFinal': finalDistanceFare,
        'holdingFareFinal': finalHoldingFare,
        'finalFare': finalFare,
        'completedAt': FieldValue.serverTimestamp(),
      });

      await db.collection('bookings').doc(bookingId).update({
        'status': 'Completed',
        'finalDistanceKm': liveDistance,
        'finalHoldingHours': hours,
        'finalDistanceFare': finalDistanceFare,
        'finalHoldingFare': finalHoldingFare,
        'finalFare': finalFare,
        'balanceAmount': max(
          0,
          finalFare -
              (NumberUtil.toDouble(
                    (await db.collection('bookings').doc(bookingId).get())
                        .data()?['advanceAmount'],
                  ) ??
                  0),
        ),
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Credit 2% cashback once after a completed trip.
      final bookingRef = db.collection('bookings').doc(bookingId);
      final bookingSnap = await bookingRef.get();
      final bookingData = bookingSnap.data() ?? <String, dynamic>{};
      if (bookingData['cashbackCredited'] != true) {
        final uid = bookingData['userId']?.toString();
        final cashback = finalFare * cashbackPercent;
        if (uid != null && cashback > 0) {
          final walletRef = db.collection('users').doc(uid);
          await db.runTransaction((tx) async {
            final walletSnap = await tx.get(walletRef);
            final current = NumberUtil.toDouble(walletSnap.data()?['walletBalance']) ?? 0;
            tx.set(walletRef, {
              'walletBalance': current + cashback,
              'walletUpdatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            tx.set(walletRef.collection('walletTransactions').doc(), {
              'type': 'cashback',
              'bookingId': bookingId,
              'amount': cashback,
              'description': 'Cashback - Booking $bookingId',
              'createdAt': FieldValue.serverTimestamp(),
            });
          });
          await bookingRef.update({
            'cashbackCredited': true,
            'cashbackAmount': cashback,
          });
        }
      }

      _liveDistanceKm = 0.0;
      _lastTripPosition = null;
      setState(() => activeBookingId = null);

      snack(
        context,
        'Trip completed. Final fare: ${money(finalFare)}',
      );
    } catch (e) {
      snack(context, 'End trip failed: $e');
    } finally {
      if (mounted) setState(() => tripEnding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverId = auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Driver Mode')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    online ? Icons.wifi : Icons.wifi_off,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          online ? 'DRIVER ONLINE' : 'DRIVER OFFLINE',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (currentPosition != null)
                          Text(
                            '${currentPosition!.latitude.toStringAsFixed(6)}, '
                            '${currentPosition!.longitude.toStringAsFixed(6)}',
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: online,
                    onChanged: (_) => toggleOnline(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (driverId == null)
            const Text('Driver login required.'),
          if (driverId != null)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db
                  .collection('bookings')
                  .where(
                    'status',
                    whereIn: const ['Confirmed', 'Trip Started'],
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Booking error: ${snapshot.error}');
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No confirmed trips.'),
                    ),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final b = doc.data();
                    final status = b['status']?.toString() ?? '';
                    final isStarted = status == 'Trip Started';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Booking ${doc.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Customer: ${b['userName'] ?? ''}'),
                            Text('Pickup: ${b['pickup'] ?? ''}'),
                            Text('Drop: ${b['drop'] ?? ''}'),
                            Text('Status: $status'),
                            const SizedBox(height: 10),
                            if (!isStarted)
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: tripStarting
                                      ? null
                                      : () => startTrip(doc.id),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('START TRIP'),
                                ),
                              ),
                            if (isStarted)
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: tripEnding
                                      ? null
                                      : () => endTrip(doc.id),
                                  icon: const Icon(Icons.stop),
                                  label: const Text('END TRIP'),
                                ),
                              ),
                            if (isStarted)
                              LiveTripMiniCard(bookingId: doc.id),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class LiveTripMiniCard extends StatelessWidget {
  final String bookingId;

  const LiveTripMiniCard({
    super.key,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('liveTrips').doc(bookingId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final t = snapshot.data!.data()!;
        final distance =
            NumberUtil.toDouble(t['liveDistanceKm']) ?? 0;
        final fare =
            NumberUtil.toDouble(t['liveFare']) ?? 0;

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Live distance: ${distance.toStringAsFixed(2)} km • '
            'Live fare: ${money(fare)}',
          ),
        );
      },
    );
  }
}

class CustomerTrackingPage extends StatelessWidget {
  final String bookingId;

  const CustomerTrackingPage({
    super.key,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Driver')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('liveTrips').doc(bookingId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(
              child: Text('Driver has not started the trip yet.'),
            );
          }

          final data = snapshot.data!.data()!;
          final lat = NumberUtil.toDouble(data['latitude']);
          final lng = NumberUtil.toDouble(data['longitude']);

          final distance =
              NumberUtil.toDouble(data['liveDistanceKm']) ?? 0;
          final fare =
              NumberUtil.toDouble(data['liveFare']) ?? 0;
          final status = data['status']?.toString() ?? 'Waiting';

          return Column(
            children: [
              Expanded(
                child: lat != null && lng != null
                    ? FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(lat, lng),
                          initialZoom: 14,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.hrride.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(lat, lng),
                                width: 60,
                                height: 60,
                                child: const Icon(
                                  Icons.local_taxi,
                                  size: 42,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : const Center(
                        child: Text('Waiting for driver location...'),
                      ),
              ),
              Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        status,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Live distance: ${distance.toStringAsFixed(2)} km',
                      ),
                      Text('Live fare: ${money(fare)}'),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String text;

  const StatusChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        text,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}

class NumberUtil {
  static double? toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }
}

String normalizeCustomerPhone(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('91') && digits.length == 12) return digits.substring(2);
  if (digits.length == 10) return digits;
  return digits;
}

String money(double value) => '₹${value.toStringAsFixed(2)}';

Widget infoLine(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 9),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

String formatDate(DateTime date) {
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  return '$dd/$mm/${date.year}';
}

void snack(BuildContext context, String message) {
  if (!context.mounted) return;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message)),
    );
}

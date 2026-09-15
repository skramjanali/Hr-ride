
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfdropcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const String backendUrl = 'https://hr-ride.onrender.com';

// Change this to the real admin phone number before production.
const String adminPhone = '+16505551234';

const double acRate = 20.0;
const double nonAcRate = 17.0;
const double holdingRate = 100.0;
const double advancePercent = 0.30;

const String vehicleName = 'Maruti Ertiga';
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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080B12),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF111722),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF101620),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
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
        title: const Text('HR RIDE'),
        actions: [
          IconButton(
            onPressed: () async {
              await auth.signOut();
              try {
                await googleSignIn.signOut();
              } catch (_) {}
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _homeHeader(user),
          const SizedBox(height: 18),
          HomeTile(
            icon: Icons.local_taxi,
            title: 'Book HR RIDE',
            subtitle: 'Book your Maruti Ertiga',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookingPage()),
            ),
          ),
          HomeTile(
            icon: Icons.receipt_long,
            title: 'My Bookings',
            subtitle: 'View booking, payment and trip status',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyBookingsPage()),
            ),
          ),
          if (isAdmin)
            HomeTile(
              icon: Icons.admin_panel_settings,
              title: 'Admin Panel',
              subtitle: 'Accept or reject bookings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPanel()),
              ),
            ),
          if (isAdmin)
            HomeTile(
              icon: Icons.directions_car,
              title: 'Driver Mode',
              subtitle: 'Start trip and share live location',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DriverModePage()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _homeHeader(User? user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              child: Icon(Icons.person),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  Text(
                    user?.displayName?.isNotEmpty == true
                        ? user!.displayName!
                        : user?.phoneNumber ?? 'HR RIDE Customer',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('$vehicleName • $serviceRegion'),
                ],
              ),
            ),
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
  DateTime travelDate = DateTime.now().add(const Duration(days: 1));
  int holdingHours = 0;

  double? distanceKm;
  int? durationMinutes;
  bool calculatingRoute = false;
  bool paying = false;

  final CFPaymentGatewayService cashfree = CFPaymentGatewayService();

  @override
  void initState() {
    super.initState();

    final user = auth.currentUser;
    nameController.text = user?.displayName ?? '';
    phoneController.text = user?.phoneNumber?.replaceFirst('+91', '') ?? '';
    emailController.text = user?.email ?? '';

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

  double get rate => vehicleType == 'AC' ? acRate : nonAcRate;

  double get distanceFare =>
      (distanceKm ?? 0) * rate;

  double get holdingFare =>
      holdingHours * holdingRate;

  double get totalAmount =>
      distanceFare + holdingFare;

  double get advanceAmount =>
      totalAmount * advancePercent;

  double get balanceAmount =>
      max(0, totalAmount - advanceAmount);

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

      setState(() {
        distanceKm = km;
        durationMinutes = minutes;
      });

      snack(
        context,
        'Distance: ${km.toStringAsFixed(1)} km'
        '${minutes != null ? ' • $minutes min' : ''}',
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
      'vehicle': vehicleName,
      'mileage': vehicleMileage,
      'region': serviceRegion,
      'vehicleType': vehicleType,
      'travelDate': Timestamp.fromDate(travelDate),
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      'chargeableKm': distanceKm,
      'ratePerKm': rate,
      'holdingHours': holdingHours,
      'holdingRate': holdingRate,
      'distanceFare': distanceFare,
      'holdingFare': holdingFare,
      'totalAmount': totalAmount,
      'advancePercent': advancePercent * 100,
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
          .setEnvironment(CFEnvironment.SANDBOX)
          .setOrderId(orderId)
          .setPaymentSessionId(paymentSessionId)
          .build();

      final payment = CFDropCheckoutPaymentBuilder()
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
        await bookingDoc.reference.update({
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

  void _onCashfreeError(dynamic error, String orderId) {
    if (!mounted) return;

    setState(() => paying = false);

    snack(
      context,
      'Payment cancelled/failed for order $orderId',
    );
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
          DropdownButtonFormField<String>(
            value: vehicleType,
            decoration: const InputDecoration(
              labelText: 'Vehicle Type',
            ),
            items: const [
              DropdownMenuItem(value: 'AC', child: Text('AC')),
              DropdownMenuItem(value: 'Non-AC', child: Text('Non-AC')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => vehicleType = value);
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: const Color(0xFF111722),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            leading: const Icon(Icons.calendar_month),
            title: const Text('Travel Date'),
            subtitle: Text(formatDate(travelDate)),
            trailing: TextButton(
              onPressed: chooseDate,
              child: const Text('CHANGE'),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                const ListTile(
                  title: Text('Holding / Waiting'),
                  subtitle: Text('₹100 per hour'),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: holdingHours > 0
                          ? () => setState(() => holdingHours--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$holdingHours hour(s)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => holdingHours++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FareCard(
            distanceKm: distanceKm,
            rate: rate,
            distanceFare: distanceFare,
            holdingFare: holdingFare,
            totalAmount: totalAmount,
            advanceAmount: advanceAmount,
            balanceAmount: balanceAmount,
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
                    : 'PAY ₹${advanceAmount.toStringAsFixed(0)} ADVANCE (30%)',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Payment is processed securely by Cashfree.',
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
              '30% ADVANCE',
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
              infoLine(
                Icons.receipt,
                'Order: ${b['orderId']}',
              ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
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
                      if (status == 'Confirmed' || status == 'Trip Started')
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
        'holdingRate': holdingRate,
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
      final startAt = (t['startedAt'] as Timestamp?)?.toDate();

      double hours = 0;
      if (startAt != null) {
        final elapsed = DateTime.now().difference(startAt).inMinutes;
        hours = elapsed / 60.0;
      }

      final finalDistanceFare = liveDistance * rate;
      final finalHoldingFare = hours * holdingRate;
      final finalFare = finalDistanceFare + finalHoldingFare;

      await tripRef.update({
        'status': 'Completed',
        'endDistanceKm': liveDistance,
        'holdingHoursFinal': hours,
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

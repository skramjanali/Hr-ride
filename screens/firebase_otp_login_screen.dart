import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firebase_phone_auth_service.dart';
import 'home_screen.dart';

class FirebaseOtpLoginScreen extends StatefulWidget {
  const FirebaseOtpLoginScreen({super.key});
  @override
  State<FirebaseOtpLoginScreen> createState() => _FirebaseOtpLoginScreenState();
}

class _FirebaseOtpLoginScreenState extends State<FirebaseOtpLoginScreen> {
  final phone = TextEditingController();
  final otp = TextEditingController();
  final auth = FirebasePhoneAuthService();
  String? verificationId;
  bool busy = false;

  void message(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> sendOtp() async {
    final n = phone.text.replaceAll(RegExp(r'\D'), '');
    if (n.length != 10) { message('Enter a valid 10-digit mobile number.'); return; }
    setState(() => busy = true);
    await auth.sendOtp(
      phoneNumber: '+91$n',
      onCodeSent: (id) {
        setState(() { verificationId = id; busy = false; });
        message('OTP sent.');
      },
      onError: (e) { setState(() => busy = false); message(e); },
    );
  }

  Future<void> verify() async {
    if (verificationId == null) { message('Send OTP first.'); return; }
    setState(() => busy = true);
    try {
      await auth.verifyOtp(verificationId: verificationId!, smsCode: otp.text.trim());
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on FirebaseAuthException catch (e) {
      setState(() => busy = false);
      message(e.message ?? 'OTP verification failed.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/hr_ride_logo.png', width: 130, height: 130),
            const SizedBox(height: 16),
            const Text('HR RIDE', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Login with mobile OTP'),
            const SizedBox(height: 24),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(prefixText: '+91 ', labelText: 'Mobile number', border: OutlineInputBorder()),
            ),
            if (verificationId != null) ...[
              TextField(
                controller: otp,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'OTP', border: OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : (verificationId == null ? sendOtp : verify),
                child: busy ? const CircularProgressIndicator() : Text(verificationId == null ? 'SEND OTP' : 'VERIFY & CONTINUE'),
              ),
            ),
            if (verificationId != null)
              TextButton(onPressed: busy ? null : sendOtp, child: const Text('Resend OTP')),
          ]),
        ),
      ),
    ),
  );
}

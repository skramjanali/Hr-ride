
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayCheckoutService {
  final Razorpay _razorpay = Razorpay();

  void initialize({
    required void Function(PaymentSuccessResponse) onSuccess,
    required void Function(PaymentFailureResponse) onFailure,
    required void Function(ExternalWalletResponse) onWallet,
  }) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onWallet);
  }

  void openCheckout({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String name,
    required String contact,
  }) {
    final options = {
      'key': keyId,
      'amount': amountPaise,
      'currency': 'INR',
      'name': name,
      'description': 'HR RIDE booking',
      'order_id': orderId,
      'prefill': {'contact': contact},
      'theme': {'color': '#111111'},
    };
    _razorpay.open(options);
  }

  void dispose() => _razorpay.clear();
}

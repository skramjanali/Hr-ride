
enum PaymentMethod { cash, upi, card }

class PaymentResult {
  final bool success;
  final String message;
  const PaymentResult(this.success, this.message);
}

class PaymentService {
  // Scaffold only. No real money movement occurs in this demo.
  Future<PaymentResult> pay({
    required double amount,
    required PaymentMethod method,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (method == PaymentMethod.cash) {
      return const PaymentResult(true, 'Cash payment selected');
    }
    return const PaymentResult(false, 'Connect a payment gateway for live payments');
  }
}

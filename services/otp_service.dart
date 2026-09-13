
class OtpService {
  // Development scaffold. Replace with Firebase/Auth provider in production.
  Future<bool> requestOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return phone.trim().length == 10;
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return phone.trim().length == 10 && otp.trim() == '123456';
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_sara/main.dart';

void main() {
  testWidgets('OTP SARA home screen renders', (tester) async {
    await tester.pumpWidget(const OtpSaraApp());
    expect(find.text('نظام OTP / SARA'), findsOneWidget);
    expect(find.text('تسجيل طفل'), findsOneWidget);
  });
}

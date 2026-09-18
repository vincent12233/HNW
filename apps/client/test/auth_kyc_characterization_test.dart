import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:india_trading_app/pages/kyc_upload_page.dart';
import 'package:india_trading_app/pages/login_page.dart';
import 'package:india_trading_app/pages/register_page.dart';
import 'package:india_trading_app/services/auth_service.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'register currently posts phone, password, and inviteCode without OTP',
    () async {
      late http.Request captured;
      await http.runWithClient(() async {
        final token = await AuthService().register(
          phone: '9876543210',
          password: 'password1',
          inviteCode: 'invite99',
        );
        expect(token, 'kyc-token');
      }, () {
        return MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'message': 'Registration successful',
              'kycToken': 'kyc-token',
              'user': {'id': 'u1', 'status': 'SUSPENDED'},
            }),
            201,
          );
        });
      });
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(captured.url.path, '/auth/register');
      expect(body.keys.toSet(), {'phone', 'password', 'inviteCode'});
      expect(body['inviteCode'], 'INVITE99');
      expect(body.containsKey('otp'), isFalse);
    },
  );

  test(
    'login currently posts phone and password, and only adds verificationCode when provided',
    () async {
      late Map<String, dynamic> body;
      await http.runWithClient(() async {
        await AuthService().login(
          phone: '9876543210',
          password: 'password1',
          verificationCode: '123456',
        );
      }, () {
        return MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'accessToken': 'a',
              'refreshToken': 'r',
              'user': {'id': 'u1', 'role': 'CLIENT', 'status': 'ACTIVE'},
              'account': {'id': 'a1'},
            }),
            200,
          );
        });
      });
      expect(body.containsKey('smsOtp'), isFalse);
      expect(body['verificationCode'], '123456');
      expect(body['phone'], isNotEmpty);
      expect(body['password'], 'password1');
    },
  );

  testWidgets('register screen keeps invite code and has no SMS OTP field', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const RegisterPage()),
    );
    expect(find.text('Invite Code'), findsWidgets);
    expect(find.text('Password'), findsOneWidget);
    expect(find.textContaining('OTP'), findsNothing);
    expect(find.textContaining('verification code'), findsNothing);
  });

  testWidgets('login shows authenticator field only after 2FA is required', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LoginPage(onSignedIn: (_) {}),
      ),
    );
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Authenticator or recovery code'), findsNothing);
    expect(find.textContaining('SMS OTP'), findsNothing);
  });

  testWidgets('KYC overview currently lists the six manual-review steps without OTP', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const KycUploadPage()),
    );
    await tester.pump();
    expect(find.text('Choose Identity Document'), findsOneWidget);
    expect(find.text('PAN Card'), findsOneWidget);
    expect(find.text('Aadhaar Card'), findsOneWidget);
    expect(find.text('Personal Details'), findsWidgets);
    expect(find.text('Upload documents'), findsWidgets);
    expect(find.text('Selfie'), findsWidgets);
    expect(find.text('Signature'), findsWidgets);
    expect(find.text('Bank Account Details'), findsWidgets);
    expect(find.text('Review & submit'), findsWidgets);
    expect(find.textContaining('OTP'), findsNothing);
    expect(find.textContaining('Aadhaar OTP'), findsNothing);
  });
}

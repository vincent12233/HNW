import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:india_trading_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Login page displays correctly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const IndiaTradingApp());
    await tester.pump();
    expect(find.text('HNW'), findsOneWidget);
    // Covers the minimum splash duration and the API warm-up timeout.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    await tester.pumpAndSettle();
    expect(find.text('HNW'), findsWidgets);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}

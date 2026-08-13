import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Login page displays correctly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const IndiaTradingApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('India Trading'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Mobile Number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
